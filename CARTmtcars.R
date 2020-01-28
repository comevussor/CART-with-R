library(rpart)
library(parallel)

head(mtcars)
plot(mtcars)

# we are trying to predict mpg

# functionalize CART algorithm

getBestTree <- function(data) {
    # get maximal tree
    myMaxTree <- rpart(data[, 1] ~ ., data[, -1], control = rpart.control(minsplit = 2, cp = 0))
    # plot(myMaxTree)
    # text(myMaxTree)
    # print(myMaxTree)
    # print(summary(myMaxTree))
    
    # get CP table of myMaxTree
    myCPtable <- myMaxTree$cptable
    # myPlotCP <- plotcp(myMaxTree)

    #get error threshold to be able to selet the best tree
    # we may have several trees with min xerr, take min xstd and then, min nsplit (must be unique in the end)
    myCPtable_sorted <- myCPtable[order(myCPtable[, 4], myCPtable[, 5], myCPtable[, 2]),]
    myThreshold <- myCPtable_sorted[1, 4] + myCPtable_sorted[1, 5]
    # print("threshold = ")
    # print(myThreshold)

    # get best CP to be able to get the best tree
    myEligibleCP <- myCPtable[myCPtable[, 4] <= myThreshold,]
    # if several trees are elegible then sort them out
    if (is.vector(myEligibleCP) == FALSE) {
        myBestCP <- myEligibleCP[myEligibleCP[, 2] == min(myEligibleCP[, 2]), 1] # must be unique
    }
    # otherwise we are done
    else {
        myBestCP <- myEligibleCP[1] # must be unique
    }
    # print("best CP =")
    # print(myBestCP)
    
    myBestTree <- rpart(data[, 1] ~ ., data[, -1], control = rpart.control(minsplit = 2, cp = myBestCP))
    # plot(myBestTree)
    # text(myBestTree)
    # print(myBestTree)
    # print(summary(myBestTree))
    getBestTree <- myBestTree
}

# OPTIONAL
# Let us determine the CART tree associated to mtcars
# myBestTree <- getBestTree(mtcars)
# unstable : different at each execution

# Let us do bagging and CART to plot error as a funciton of K (number of bootstrap sample)

# split our data without replacement into a leanrning sample and and a testing sample
getSplit <- function(data, ts) {
    # ts = testing sample size
    n <- nrow(data)
    testIndex <- sample(1:n, ts)
    mySplit <- list(learnData = data[-testIndex,], testData = data[testIndex,])
}

# create a bootstrap sample with replacement of size bs
getBootstrap <- function(data, bs) { # bs = bagsize
    len <- nrow (data)
    myRows <- sample(1:len, len, replace = TRUE)
    getBootstrap <- data[myRows,]
}

# from splited data, get error of prediction with a bagging of K bootstrap samples of size bs computed on a test sample of size ts 
getPoint <- function(learnData, testData, K, ts, bs) { # ts = test size, bs = bootstrap sample size
    # get K predictions of K boostrap samples of size bs from data (first column of test is real Y values)
    myKpredict <- replicate(K, predict(getBestTree(getBootstrap(learnData, bs)), newdata = testData[-1]))
    # get prediction out of K predictions
    myBagPredict <- rowMeans(myKpredict)
    # get norm 2 error between predicition and real value
    getPoint <- norm(myBagPredict - testData[1], type = "2") / length(myBagPredict)
}

# prepare split for our test with bagging going from 2 to Kmax
prepareCompute <- function(Kmax) {
    mySplit <- getSplit(mtcars, 10)
    myK <- sample(2:Kmax, Kmax - 1)
    myPrep <- list(learnData = mySplit$learnData, testData = mySplit$testData, myK = myK)
    return (myPrep)
}

# process our test and plot error vs K without parrallelization
simpleCompute <- function(Kmax) {
    myPrep <- prepareCompute(Kmax)

    myErr <- lapply(myPrep$myK, function(x) { return(getPoint(myPrep$learnData, myPrep$testData, x, 10, nrow(mtcars))) })

    return(as.vector(myErr))
}

# process our test and plot error vs K with 11 threads
parCompute <- function(Kmax) {
    myParPrep <- prepareCompute(Kmax)
    myEnvir <- environment()

    # create a cluster
    numCores <- detectCores()
    cl <- makeCluster(numCores)

    # export useful objects in the cluster
    clusterExport(cl, list("getBestTree","getSplit", "getBootstrap", "getPoint", "prepareCompute"))
    clusterExport(cl, list("Kmax", "myParPrep"), envir = myEnvir)

    # parallelize sapply
    myErr <- parSapply(cl, myParPrep$myK, FUN = function(x) { return(getPoint(myParPrep$learnData, myParPrep$testData, x, 10, nrow(mtcars))) })
    
    # close the cluster
    stopCluster(cl)

    plot(myParPrep$myK, myErr)
    return(as.vector(myErr))
}


myKmaxList <- c(50, 100, 200)
myResults <- lapply(myKmaxList, FUN = function(x) { list(system.time(simpleCompute(x)), system.time(parCompute(x))) })
names(myResults) <- myKmaxList
myResults

system.time(parCompute(500))
system.time(simpleCompute(500))
