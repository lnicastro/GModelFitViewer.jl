#!/bin/bash
#
# Create a stand-alone plotting html file from "viewer.html" or another input GFitViewer html file.
#
# Default output: viewersa.html
#
# Usage: mksaviewer.sh [OPTIONS]
#
#
# LN @ INAF-OAS June 2020.  Last change: 07/04/2021
#--

# Reference html file
  REF_HTML=viewer.html

# Default html file
  DEF_HTML=viewersa.html

# By default do not overwrite existing output html
  do_overwrite=false

# Minimal help
  print_help() {
    echo -e "Usage:\n  $0 [-hiOo]" \
	"\n  -h  print this help" \
	"\n  -i  'infile'	input html file (def. $REF_HTML)" \
	"\n  -O  overwrite existing output file" \
	"\n  -o 'outfile'        output html file (def. $DEF_HTML)"
  }


# User passed options, one argument at a time.
  while getopts "hi:o:O" o; do
    case "${o}" in

    h)
	print_help
	exit 0 ;;

    i)
	REF_HTML=${OPTARG}
	;;

    o)
 	if [[ "x${OPTARG}" = "x" || "${OPTARG}" = "auto" ]]; then
	  OUT_HTML=$DEF_HTML
	else
          OUT_HTML=${OPTARG}
	fi ;;

    O)
	do_overwrite=true ;;

    *)
	print_help
	exit 1 ;;
    esac
  done

  shift $((OPTIND-1))
echo "REF_HTML is $REF_HTML"

# Check it exists
  if [ ! -f $REF_HTML ]; then
	echo -e "'$REF_HTML' does not exist in your working dir. ${PWD}"
	exit 1
  fi

# The output html file name, if not given
  if [ "x$OUT_HTML" = 'x' ]; then
	OUT_HTML=$DEF_HTML
  else
# Check for extension name: force to be .html
	if [[ ! $OUT_HTML =~ \.html$ ]]; then
		OUT_HTML=${OUT_HTML%.*}".html"
	fi
  fi


# Check for existing file
  if [[ -f $OUT_HTML && "$do_overwrite" = false ]]; then
	echo -e "'$OUT_HTML' exists. Use -O to force overwrite."
	exit 1
  fi

# Replace the JS external links with their (local) content
  LOCDIR=../local
  jsfiles=( amcharts_core.js amcharts_charts.js amcharts_animated.js )
 
# ... up to the @Remote marker
  sed -n '/@Remote/q;p' $REF_HTML > $OUT_HTML

# ... then the list of JS files


  for JS_FILE in "${jsfiles[@]}"
  do
	echo "<script>" >> $OUT_HTML
	cat $LOCDIR/$JS_FILE >> $OUT_HTML
	echo "" >> $OUT_HTML
	echo "</script>" >> $OUT_HTML
  done


# ... from the @EndRemote marke to the end
  sed -e '1,/@EndRemote/ d' $REF_HTML >> $OUT_HTML

  echo "'$OUT_HTML' ready."

  exit 0
