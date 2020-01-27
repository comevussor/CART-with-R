# CART-with-R
CART algorithm bagging K bootstrap samples - plot prediction error vs K -  parallelization gain

We are using the default mtcars data set in R, trying to predict mpg as a response to all other explanatory variables.
- check the assumption that the best tree without bagging is an unstable result.
- split our data into a learning set and a testing set.
- create K bootstrap samples of size the size of the learning set.
- get a best tree for each sample, average out the predictions and compute a 2-norm prediction error on the bag.
- vary K from 2 to Kmax. We take successively Kmax = 50, 100, 200, 500.
- we parallelize the previous step with one thread per core and see the gain in time.

Warning : I have commented out the test with Kmax=500 without parallelization since it can take more than 15 minutes.

I'm using a processor Inter Core i7-8700 (12 cores) and I got :

Kmax      without parallel      with parallel
50        6.62sec               6.17sec
100       25.78sec              10.19sec
200       235.39sec             27.16sec
500       >10min                140.08sec

Note that parallelization is not optimized because we have a replicate function executed separately in each thread but we can still observe a very good effect.
