This directory contains a few Python scripts for training and running
[MonoBoost classifiers](https://github.com/chriswbartley/monoboost).

## Get Started

Before using the scripts, make sure you have the following packages installed
(all of them are required by monoboost):

* cvxopt
* monoboost
* numpy

To install any of them, it should suffice to do `pip install <package-name>`.

## Training MonoBoost models

First, make sure you are in the `$REPO-ROOT/tools/monoboost` directory -
currently, I assume the scripts to be executed from there - if needed, I can
change this. Then do:

```
$ ./mbtrain.py
```

This will start the training process using the standard parameter values. To
see the full list of available command-line options, run it with option `-h`.

The `mbtrain.py` script iterates over all datasets specified as a global
variable and train a classifier, which is then saved in directory `models`.

## Running the classifier

Once a desired model is trained, it can be run using command:

```
$ ./mbrun.py -m models/<model.pkl> <comma-separated-values>
```

The comma-separated values represent a target instance that we want to
get the prediction for. The prediction will then be calculated using the model
and printed as an integer to `STDIN`.

### Example

```
$ ./mbrun.py -m models/bankruptcy-risk.pkl 2,1,1,1,1,3,2,2,4,4,2,1
3
```
