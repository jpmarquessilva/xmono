#!/usr/bin/env python
#-*- coding:utf-8 -*-
##
## mbtrain.py
##
##  Created on: Jan 31, 2021
##      Author: Alexey Ignatiev
##      E-mail: alexey.ignatiev@monash.edu
##

# imported modules
#==============================================================================
from dataset import Dataset
import getopt
import monoboost as mb
import numpy as np
import os
import pickle
import random
import sys


# global variables
#==============================================================================
# datasets = ['ERA.arff', 'ESL.arff', 'LEV.arff', 'SWD.arff']
datasets = ['bankruptcy-risk.csv', 'pima.arff']


#
#==============================================================================
def parse_options():
    """
        Parses command-line option
    """

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'e:E:hl:m:t:vV:',
                ['eta', 'estims', 'help', 'learners', 'mtype', 'ltype',
                    'verbose', 'vs'])
    except getopt.GetoptError as err:
        sys.stderr.write(str(err).capitalize())
        usage()
        sys.exit(1)

    eta = 0.25
    estims = 10
    learners = 2
    ltype = 'two-sided'
    mtype = 'mb'
    verbose = 0
    vs = []

    for opt, arg in opts:
        if opt in ('-e', '--eta'):
            eta = float(arg)
        elif opt in ('-E', '--estims'):
            estims = int(arg)
        elif opt in ('-h', '--help'):
            usage()
            sys.exit(0)
        elif opt in ('-l', '--learners'):
            learners = int(arg)
        elif opt in ('-m', '--mtype'):
            mtype = str(arg)
        elif opt in ('-t', '--ltype'):
            ltype = str(arg)
        elif opt in ('-v', '--verbose'):
            verbose += 1
        elif opt in ('-V', '--vs'):
            vs.append(float(arg))
        else:
            assert False, 'Unhandled option: {0} {1}'.format(opt, arg)

    if not vs:
        vs = [0.01, 0.2, 0.4, 0.6, 0.8, 1.0]

    return eta, estims, learners, ltype, mtype, verbose, vs


#
#==============================================================================
def usage():
    """
        Prints usage message.
        """

    print('Usage:', os.path.basename(sys.argv[0]), '[options]')
    print('Options:')
    print('        -e, --eta=<float>       Magic ETA parameter (default: 0.25)')
    print('        -E, --estims=<int>      Number of estimators (default: 10)')
    print('        -h, --help              Show this message')
    print('        -l, --learners=<int>    Number of learners (default: 2)')
    print('        -m, --mtype=<string>    Model type (\'mb\' or \'mbensemble\')')
    print('        -t, --ltype=<string>    Learner type (\'one-sided\' or \'two-sided\')')
    print('        -v, --verbose           Be verbose')
    print('        -V, --vs=<float>        Error value to consider (may be multiple)')


# main
#==============================================================================
if __name__ == '__main__':
    eta, estims, learners, ltype, mtype, verbose, vs = parse_options()

    for ds in datasets:
        data = Dataset(os.path.join(os.path.dirname(os.path.abspath(__file__)),
            'datasets', ds))

        incr = list(range(1, data.nfeats + 1))  # increasing features
        decr = []  # decreasing features

        if mtype == 'mb':
            print('training a monoboost model for', ds)

            # creating monoboost object
            mb_clf = mb.MonoBoost(n_feats=data.nfeats, incr_feats=incr,
                    decr_feats=decr, num_estimators=estims,
                    fit_algo='L2-one-class', eta=eta, vs=vs, verbose=verbose,
                    learner_type=ltype)
        else:
            print('training a monoboost-ensemble model for', ds)

            # additional parameters
            random.seed()
            random_state = random.randint(1, 2 ** 32)
            learner_v_mode = 'random'
            sample_fract = 0.5
            standardise = True

            # creating monoboost-ensemble object
            mb_clf = mb.MonoBoostEnsemble(n_feats=data.nfeats, incr_feats=incr,
                decr_feats=decr, num_estimators=estims,
                fit_algo='L2-one-class', eta=eta, vs=vs, verbose=verbose,
                learner_type=ltype, learner_num_estimators=learners,
                learner_eta=eta, learner_v_mode=learner_v_mode,
                sample_fract=sample_fract, random_state=random_state,
                standardise=standardise)

        # translating data to numpy's arrays
        datax, datay = data.as_arrays()
        datax = np.array(datax)
        datay = np.array(datay, dtype=np.int)  # integers for classification, floats for regression

        # training monoboost
        mb_clf.fit(datax, datay)

        # running monoboost
        y_pred = mb_clf.predict(datax)

        # monoboost seems to do regression, unclear why! :(
        # (it might be that the tool supports binary classification only)
        # doing rounding here to translate the values back to classes
        y_pred = np.array([round(v) for v in y_pred])

        # computing accuracy
        acc = np.sum(datay == y_pred) / len(datay)
        print('accuracy:', acc)

        # serializing the classifier into a pickle file
        if not os.path.isdir('models'):
            os.mkdir('models')

        with open(os.path.join('models', '{0}.pkl'.format(os.path.splitext(ds)[0])), 'wb') as fobj:
            pickle.dump(mb_clf, fobj)
