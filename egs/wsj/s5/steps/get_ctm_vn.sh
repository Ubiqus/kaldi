#!/bin/bash
# Copyright Johns Hopkins University (Author: Daniel Povey) 2012.  Apache 2.0.

# This script produces CTM files from a decoding directory that has lattices
# present.
#

# **************************************************************************************************************
# modified version by vn 27/04/2016 with lattice-to-ctm-conf to get the confidences - original kept in directory
# **************************************************************************************************************

# begin configuration section.
cmd=run.pl
stage=0
frame_shift=0.03
min_lmwt=5
max_lmwt=20
use_segments=true # if we have a segments file, use it to convert
                  # the segments to be relative to the original files.
#end configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh
. parse_options.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $0 [options] <data-dir> <lang-dir|graph-dir> <decode-dir>"
  echo " Options:"
  echo "    --cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "    --stage (0|1|2)                 # start scoring script from part-way through."
  echo "    --use-segments (true|false)     # use segments and reco2file_and_channel files "
  echo "                                    # to produce a ctm relative to the original audio"
  echo "                                    # files, with channel information (typically needed"
  echo "                                    # for NIST scoring)."
  echo "    --frame-shift (default=0.01)    # specify this if your lattices have a frame-shift"
  echo "                                    # not equal to 0.01 seconds"
  echo "e.g.:"
  echo "$0 data/train data/lang exp/tri4a/decode/"
  echo "See also: steps/get_train_ctm.sh"
  exit 1;
fi

data=$1
lang=$2 # Note: may be graph directory not lang directory, but has the necessary stuff copied.
dir=$3

model=$dir/../final.mdl # assume model one level up from decoding dir.


for f in $lang/words.txt $model $dir/lat.1.gz; do
  [ ! -f $f ] && echo "$0: expecting file $f to exist" && exit 1;
done

name=`basename $data`; # e.g. eval2000

mkdir -p $dir/scoring/log

if [ $stage -le 0 ]; then
  if [ -f $data/segments ] && $use_segments; then
    f=$data/reco2file_and_channel
    [ ! -f $f ] && echo "$0: expecting file $f to exist" && exit 1;
    filter_cmd="utils/convert_ctm_vn.pl $data/segments $data/reco2file_and_channel"
  else
    filter_cmd=cat
  fi

# modified version by vn 27/04/2016 with lattice-to-ctm-conf to get the confidences - original kept in directory
  if [ -f $lang/phones/word_boundary.int ]; then
    $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/get_ctm.LMWT.log \
      set -o pipefail '&&' mkdir -p $dir/score_LMWT/ '&&' \
      lattice-align-words $lang/phones/word_boundary.int $model "ark:gunzip -c $dir/lat.*.gz|" ark:- \| \
      lattice-to-ctm-conf --inv-acoustic-scale=LMWT --frame-shift=$frame_shift ark:- - \| \
      utils/int2sym.pl -f 5 $lang/words.txt \| \
      $filter_cmd '>' $dir/score_LMWT/$name.ctm || exit 1;
  else
    if [ ! -f $lang/phones/align_lexicon.int ]; then
      echo "$0: neither $lang/phones/word_boundary.int nor $lang/phones/align_lexicon.int exists: cannot align."
      exit 1;
    fi
# modified version by vn 27/04/2016 with lattice-to-ctm-conf to get the confidences - original kept in directory
    $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/get_ctm.LMWT.log \
      set -o pipefail '&&' mkdir -p $dir/score_LMWT/ '&&' \
      lattice-align-words-lexicon $lang/phones/align_lexicon.int $model "ark:gunzip -c $dir/lat.*.gz|" ark:- \| \
      lattice-to-ctm-conf --inv-acoustic-scale=LMWT --frame-shift=$frame_shift ark:- - \| \
      utils/int2sym.pl -f 5 $lang/words.txt \| \
      $filter_cmd '>' $dir/score_LMWT/$name.ctm || exit 1;
  fi
fi


