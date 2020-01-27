library(rpart)
library(parallel)

head(mtcars)
plot(mtcars)

# we are trying to predict mpg
# functionalize CART algorithm

# step 1 : get maximal tree
getMaxTree <- function(data) { # data is supposed to be Y in first column and X in others
    maxTree <- rpart(data[, 1] ~ ., data[, -1], control = rpart.control(minsplit = 2, cp = 0))
    # plot(maxTree)
    # text(maxTree)
    # print(maxTree)
    # print(summary(maxTree))
    getMaxTree <- maxTree
}

# step 2 : get error threshold to be able to selet the best tree
getThreshold <- function(maxTree) {
    myCPtable <- maxTree$cptable
    # myPlotCP <- plotcp(maxTree)
    # we may have several trees with min xerr, take min xstd and then, min nsplit (must be unique in the end)
    myCPtable_sorted <- myCPtable[order(myCPtable[, 4], myCPtable[, 5], myCPtable[, 2]),]
    getThreshold <- myCPtable_sorted[1,4]+myCPtable_sorted[1,5]
}

# get best CP to be able to get the best tree
getBestCP <- function(maxTree, bestThreshold) {
    myCPtable <- maxTree$cptable
    myEligibleCP <- myCPtable[myCPtable[, 4] <= bestThreshold,]
    # if several trees are elegible then sort them out and select the best
    if (is.vector(myEligibleCP) == FALSE) {
        myBestCP <- myEligibleCP[myEligibleCP[, 2] == min(myEligibleCP[, 2]), 1] # must be unique
    }
    # otherwise we are done
    else {
        myBestCP <- myEligibleCP[1] # must be unique
    }
}

getBestTree <- function(data) {
    myMaxTree <- getMaxTree(data)
    myThreshold <- getThreshold(myMaxTree)
    # print("threshold = ")
    # print(myThreshold)
    myBestCP <- getBestCP(myMaxTree, myThreshold)
    # print("best CP =")
    # print(myBestCP)
    myBestTree <- rpart(data[, 1] ~ ., data[, -1], control = rpart.control(minsplit = 2, cp = myBestCP))
    # plot(myBestTree)
    # text(myBestTree)
    # print(myBestTree)
    # print(summary(myBestTree))
    getBestTree <- myBestTree
}

# Let us determine the CART tree associated to mtcars
myBestTree <- getBestTree(mtcars)
# unstable : different at each execution

# Let us do bagging and CART to plot error as a funciton of K (number of bootstrap sample)

# split our data without replacement into a leanrning sample and and a testing sample
getSplit <- function(data, ts) {
    # ts = testing sample size
    n <- nrow(data)
    testIndex <- sample(1:n, ts)
    mySplit <- list(learn = data[-testIndex,], test = data[testIndex,])
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
    getPoint <- norm(myBagPredict - testData[1], type = "2")
}

# prepare split for our test with bagging going from 2 to Kmax
prepareCompute <- function(Kmax) {
    mySplit <- getSplit(mtcars, 10)
    myLearn <- mySplit$learn
    myTest <- mySplit$test
    myK <- 2:Kmax
    myPrep <- list(myLearn, myTest, myK)
    names(myPrep) <- list ("myLearn", "myTest", "myK")
    return (myPrep)
}

# process our test and plot error vs K without parrallelization
simpleCompute <- function(Kmax) {
    myPrep <- prepareCompute(Kmax)
    myErr <- lapply(myPrep$myK, function(x) { return(getPoint(myPrep$myLearn, myPrep$myTest, x, 10, nrow(mtcars))) })
    plot(myPrep$myK, myErr)
    return(as.vector(myErr))
}

# process our test and plot error vs K with as many threads as the number of cores of the machine
parCompute <- function(Kmax) {
    myPrep <- prepareCompute(Kmax)
    myLearn <- myPrep$myLearn
    myTest <- myPrep$myTest
    myK <- myPrep$myK

    # create a cluster
    numCores <- detectCores()
    cl <- makeCluster(numCores)
    # export useful objects in the cluster
    clusterExport(cl, list("getMaxTree", "getThreshold", "getBestTree", "getBestCP", "getBootstrap", "getPoint", "myLearn", "myTest", "myK"))
    # parallelize sapply
    myErr <- parSapply(cl, myPrep$myK, FUN = function(x) { return(getPoint(myPrep$myLearn, myPrep$myTest, x, 10, nrow(mtcars))) }, simplify = simplify)
    # close the cluster
    stopCluster(cl)

    plot(myPrep$myK, myErr)
    return(as.vector(myErr))
}

system.time(simpleCompute(50))
system.time(parCompute(50))

system.time(simpleCompute(100))
system.time(parCompute(100))

system.time(simpleCompute(200))
system.time(parCompute(200))

# system.time(simpleCompute(500))
system.time(parCompute(500))
