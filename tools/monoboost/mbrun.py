#!/usr/bin/env python
#-*- coding:utf-8 -*-
##
## mbrun.py
##
##  Created on: Jan 31, 2021
##      Author: Alexey Ignatiev
##      E-mail: alexey.ignatiev@monash.edu
##

# imported modules
#==============================================================================
import getopt
import monoboost as mb
import numpy as np
import os
import pickle
import sys


#
#==============================================================================
def parse_options():
    """
        Parses command-line option
    """

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'hm:', ['help', 'model'])
    except getopt.GetoptError as err:
        sys.stderr.write(str(err).capitalize())
        usage()
        sys.exit(1)

    # target model
    model = None

    for opt, arg in opts:
        if opt in ('-h', '--help'):
            usage()
            sys.exit(0)
        elif opt in ('-m', '--model'):
            model = str(arg)
        else:
            assert False, 'Unhandled option: {0} {1}'.format(opt, arg)

    return model, [float(v) for v in args[0].strip().split(',')]


#
#==============================================================================
def usage():
    """
        Prints usage message.
        """

    print('Usage:', os.path.basename(sys.argv[0]), '[options] comma-separated-values')
    print('Options:')
    print('        -m, --model=<string>    Path to monoboost model')
    print('        -h, --help              Show this message')


# main
#==============================================================================
if __name__ == '__main__':
    model, inst = parse_options()

    # loading the pickle object and extracing the model
    with open(model, 'rb') as fobj:
        mb_clf = pickle.load(fobj)

    # predicting and reporting the class
    # (note that the class is rounded as monoboost
    # does regression rather than classification)
    print(int(round(mb_clf.predict(np.array([inst]))[0])))
