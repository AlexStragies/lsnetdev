# lsnetdev
A simple bash script showing hierarchy of networking devices.

The script is inspired by the script
https://github.com/zabojcampula/show-net-devices-tree
written/published in response to this question at StackExchange:
http://unix.stackexchange.com/questions/328754.

The goal is to show network adapters in a tree to where the dependecies
between particular adapters are clearly visible.
The script examines some files and folder under /sys/class/net/, /proc/net/ 
builds the tree wit 

The hierarchy tree can be show from bottom up or from top to bottom.
Output formats are UTF, TREE, or GraphViz

```
Options:
  -u   prints tree bottom-up (default). Physical devices are roots of the tree.
  -d   prints tree top-down. Logical devices are roots of the tree.
  -s X connect to host X via SSH to query information
  -t   Use 'tree' to print the tree by constructing a tree in TMP (default).
  -G   Print GraphViz Syntax graph, node and edge definitions.
  -g   Print GraphViz Syntax node and edge definitions only.
  -l   use UTF8 characters (default, if 'tree' is not installed).
```

Example:

```
$ ./nettree.sh -u
usbmesh
└── bat0
    └── vswitch
        ├── homev
        │   └── home
        └── iso
wlp1s0

$ ./nettree.sh -d -l
wlp1s0
home ━┓
      ┗━ homev ━┓
                ┗━ vswitch ━┓
                            ┗━ bat0 ━┓
                                     ┗━ usbmesh
iso ━┓
     ┗━ vswitch ━┓
                 ┗━ bat0 ━┓
                          ┗━ usbmesh
```
