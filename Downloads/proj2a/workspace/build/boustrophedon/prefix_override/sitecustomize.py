import sys
if sys.prefix == '/usr':
    sys.real_prefix = sys.prefix
    sys.prefix = sys.exec_prefix = '/acct/mcs46/Downloads/proj2a/workspace/install/boustrophedon'
