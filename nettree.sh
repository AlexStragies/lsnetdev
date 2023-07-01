#!/bin/bash

DIRECTION="UP"
UTF=""
TREE=""
GV=""
which tree >/dev/null && TREE=1 || UTF=1

function usage() {
   cat << USAGEEND

The script prints network devices hierarchy as a tree view.
Possible arguments:
  -u   prints tree bottom-up (default). Physical devices are roots of the tree.
  -d   prints tree top-down. Logical devices are roots of the tree.
  -s X connect to host X via SSH to query information
  -t   Use 'tree' to print the tree by constructing a tree in TMP (default).
  -G   Print GraphViz Syntax graph, node and edge definitions.
  -g   Print GraphViz Syntax node and edge definitions only.
  -l   use UTF8 characters (default, if 'tree' is not installed).

USAGEEND
}

function print() {
   local indent="$1"; shift
   local firstrun=1; if [ "$1" = "1" ]; then firstrun=0; shift; fi
   while [ -n "$1" ]; do
     local D="${1# *}"
     [ "$firstrun" = 1 -a -n "${devicesup[$D]}" ] && shift && continue; 
     echo -n "$indent ┗━ $D";
     if [ -z "${devicesdown[$D]}" ]; then echo ; else
       echo " ━┓";
       print "$(echo \ \ $D\ \ \ | sed 's/./ /g')$indent" 1 ${devicesdown[$D]}
     fi 
     shift;
   done
}

function buildFolderTree() {
  local firstrun=1; if [ "$1" = 1 ]; then firstrun=0; shift; fi
  while [ -n "$1" ]; do
    local D=${1# *}
    [ "$firstrun" = 1 -a -n "${devicesup[$D]}" ] && shift && continue;
    mkdir $D
    if [ -n "${devicesdown[$D]}" ]; then
      cd $D;
      for P in ${devicesdown[$D]}; do buildFolderTree 1 "$P";done
      cd ..
    fi 
    shift;
  done
}

function addRelation() {
  local A="$1"
  local B="$2"
  local props="$3"
  [ "$DIRECTION" = "UP" ] && C="$A" && A="$B" && B="$C"
  conns["\"$A\" -- \"$B\""]="$props"
  devicesdown[$A]="${devicesdown[$A]} $B"
  devicesup[$B]="${devicesup[$B]} $A"
}

while [ ! -z "$1" ]; do
    case "$1" in
        -d) DIRECTION=DOWN               ;;
        -u) DIRECTION=UP                 ;;
        -t) GV="";GVNE="";TREE=1 ;UTF="" ;;
        -G) GV=1 ;GVNE=1 ;TREE="";UTF="" ;;
        -g) GV="";GVNE=1 ;TREE="";UTF="" ;;
        -l) GV="";GVNE="";TREE="";UTF=1  ;;
        -s) PFX="ssh -M $2"
            shift
            ;;
        -h) usage ; exit 0               ;;
         *) usage ; exit 1               ;;
   esac
   shift
done


declare -A devices
declare -A devicesup
declare -A devicesdown
declare -A conns
SCN="/sys/class/net/"
for CDEV in $($PFX find /sys/class/net/ ! -name lo -type l |sort); do
  DCLASS="RJ45"
  NDEV=$(basename $CDEV)
  devices[$NDEV]=""
  $PFX readlink $CDEV | grep -q devices/virtual &&   DCLASS="virtual"
  $PFX [ -e $CDEV/bonding/  ]                   &&   DCLASS="bond"
  $PFX [ -e $CDEV/phy80211/ ]                   &&   DCLASS="wireless"
  $PFX [ -e $CDEV/dsa/      ]                   &&   DCLASS="dsa"
  $PFX [ -e $CDEV/bridge/   ]                   && { DCLASS="bridge"
    $PFX grep -q 1 $CDEV/bridge/vlan_filtering  &&   DCLASS="switch"
  }
  $PFX grep -q 512 $CDEV/type                   && { DCLASS="ppp"
    PNPP="/proc/net/pppoe"
    $PFX [ -e $PNPP ] && P=$($PFX cat $PNPP | awk 'NR==2{print $3}')
    [ -n "$P" ] && $PFX [ -e $SCN/$P ] && {
      addRelation "$NDEV" "$P" 'label="PPPoE"'
    }  
  }
  for LOW in $($PFX find $CDEV/ -name 'lower_*'); do
    LOW=${LOW#*_}
    addRelation "$NDEV" "$LOW" 'label=""' 
  done 
  devices[$NDEV]="label=\"${NDEV}\""
  devices[$NDEV]="${devices[$NDEV]}, class=\"${DCLASS}\""
done

[ -n "$GV" ] && {
  echo 'graph iftree {' 
}
[ -n "$GVNE" ] && {
  for iDEV in "${!devices[@]}"; do
    echo "  \"${iDEV}\"["${devices[$iDEV]}"];"
  done
  for conn in "${!conns[@]}"; do
    echo \ \ $conn[${conns[$conn]}]\;;
  done
}
[ -n "$GV" ] && { echo '}'; }

if [ "$TREE" = "1" ]; then
  TMPD=$(mktemp -qd)
  cd $TMPD
  buildFolderTree "${!devices[@]}";
  tree --noreport * 
  find $TMPD -delete
fi
if [ "$UTF" = "1" ]; then
  print "" "${!devices[@]}" | colrm 1 4
fi
