# xmono

xmono implements the algorithms described in the following paper:

João Marques-Silva, Thomas Gerspacher, Martin C. Cooper, Alexey Ignatiev, Nina Narodytska:
Explanations for Monotonic Classifiers. CoRR abs/2106.00154 (2021)

To run the tool, a number of examples are available in the run-xmono script. (All scripts are under the ./scripts folder.)

To add an example, one should understand how existing examples have been configured, and adapt accordingly. The bottom line is that one must be able to run the classifier from inside the xmono script.

Besides the examples shown in the run-xmono script, xmono has been used for validating results in other projects, e.g.

Xuanxiang Huang, Yacine Izza, Alexey Ignatiev, Joao Marques-Silva: On Efficiently Explaining Graph-Based Classifiers. CoRR abs/2106.01350 (2021)

### Command line options

The list of command line options of xmono can be obtained by running xmono with the '-h' option.


### Additional tools

The ./tools folder contains a number of external tools, that are used either by xmono, or by some of the classifiers integrated with xmono.

* Glucose SAT solver: [https://www.labri.fr/perso/lsimon/glucose/](https://www.labri.fr/perso/lsimon/glucose/)

* Monoboost, monotone tree ensemble classifier: [https://github.com/chriswbartley/monoboost](https://github.com/chriswbartley/monoboost)

* COMET, monotonic NNs: [https://github.com/AishwaryaSivaraman/COMET](https://github.com/AishwaryaSivaraman/COMET)

* OptiMathSAT, SMT optimizer used by COMET: [http://optimathsat.disi.unitn.it/](http://optimathsat.disi.unitn.it/)

These tools are included solely for the purpose of  facilitating testing. xmono only requires a SAT solver, and only for enumerating explanations.