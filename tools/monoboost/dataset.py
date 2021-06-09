#!/usr/bin/env python
#-*- coding:utf-8 -*-
##
## dataset.py
##
##  Created on: Jan 31, 2021
##      Author: Alexey Ignatiev
##      E-mail: alexey.ignatiev@monash.edu
##

import itertools


#
#==============================================================================
class Instance(object):
    """
        Represents one instance.
    """

    def __init__(self, array):
        """
            Basic constructor.
        """

        self.feats = tuple(array[:-1])
        self.label = array[-1]

    def ge(self, other, attr):
        """
            Greater-or-equal for a given attribute
            (defined wrt. partial monotonicity).
        """

        return self.feats[attr] >= other.feats[attr] and \
                all([self.feats[a] == other.feats[a] for a in range(len(self.feats)) if a != attr])

    def gt(self, other, attr):
        """
            Greater-than for a given attribute
            (defined wrt. partial monotonicity).
        """

        return self.feats[attr] > other.feats[attr] and \
                all([self.feats[a] == other.feats[a] for a in range(len(self.feats)) if a != attr])

    def le(self, other, attr):
        """
            Less-or-equal for a given attribute
            (defined wrt. partial monotonicity).
        """

        return self.feats[attr] <= other.feats[attr] and \
                all([self.feats[a] == other.feats[a] for a in range(len(self.feats)) if a != attr])

    def lt(self, other, attr):
        """
            Less-than for a given attribute
            (defined wrt. partial monotonicity).
        """

        return self.feats[attr] < other.feats[attr] and \
                all([self.feats[a] == other.feats[a] for a in range(len(self.feats)) if a != attr])

    def __str__(self):
        """
            Magic string method.
        """

        return '{0} . {1}'.format(' '.join([str(v) for v in self.feats]), self.label)


#
#==============================================================================
class Dataset(object):
    """
        Class for storing a dataset.
    """

    def __init__(self, filename=None):
        """
            Basic constructor.
        """

        self.attr = []
        self.data = []

        if filename:
            if filename.endswith('.arff'):
                self.read_arff(filename)
            elif filename.endswith('.csv'):
                self.read_csv(filename)

        self.nfeats = len(self.attr) - 1

    def read_arff(self, filename):
        """
            Read a dataset from a ARFF file.
        """

        with open(filename, 'r') as fobj:
            data_started = False  # dummy flag

            for line in fobj:
                line = line.strip()
                if line and line[0] != '%':
                    if data_started:
                        inst = Instance([float(val) for val in line.split(',')])
                        self.data.append(inst)
                    elif line == '@data':
                        data_started = True
                        continue
                    elif line.startswith('@attribute'):
                        self.attr.append(line.split()[1])

    def read_csv(self, filename):
        """
            Read a dataset from a CSV file.
        """

        with open(filename, 'r') as fobj:
            lines = fobj.readlines()
            self.attr = lines.pop(0).split(',')

            for line in lines:
                line = line.strip()
                if line:
                    inst = Instance([float(val) for val in line.split(',')])
                    self.data.append(inst)

    def as_arrays(self):
        """
            Return an array of arrays represening all the data.
        """

        datax, datay = [], []

        for inst in self:
            datax.append(list(inst.feats))
            datay.append(inst.label)

        return datax, datay

    def __len__(self):
        """
            Access to data length.
        """

        return len(self.data)

    def __iter__(self):
        """
            Basic iterator over samples.
        """

        for sample in self.data:
            yield sample

    def __getitem__(self, key):
        """
            Read-access to a given sample.
        """

        return self.data[key]

    def __setitem__(self, key, value):
        """
            Write-access to a given sample.
        """

        self.data[key] = value

    def __str__(self):
        """
            Magic string method.
        """

        ret = 'attrs: {0}'.format(' '.join(self.attr))

        for inst in self.data:
            ret += str(inst) + '\n'

        return ret.rstrip()

    def is_monotone(self, attr):
        """
            Check if the data is partially monotonic on a given attribute.
            Return +1 if the function increases when increasing the attribute
            and -1 if the function decreases. Return 0 if it is not monotonic.
            Note: the method does not handle noisy data!
        """

        for a in range(len(self.attr) - 1):
            incr, decr = 0, 0

            for i, j in itertools.combinations(range(len(self)), 2):

                    if self.data[i].gt(self.data[j], a):
                        if self.data[i].label > self.data[j].label:
                            incr += 1

                    elif self.data[i].lt(self.data[j], a):
                        if self.data[i].label > self.data[j].label:
                            decr += 1

            if (incr and decr) or (not incr and not decr):
                # this may be problematic as we do not handle noisy data
                return 0
            elif incr:
                return 1
            else:  # decr
                return -1
