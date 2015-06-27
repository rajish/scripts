#!/bin/bash

WATERTEXT=yonyo
FONT=Helvetica
GRAVITY=south
GEOMETRY=+0+10
SCALE=80
ROTATION=0
ORIENT1=
STRIP=
ORIENT2=y

usage()
{
    cat<<EOF
watermark.sh by Radzisław Galler <rgaller at gazeta.pl>
Usage:
    $0 [options] files

Where options are:
    -f <font>     - select font for the watermark (default: $FONT)
    -t <text>     - text of the watermark (default: $WATERTEXT)
    -g <gravity>  - watermark placement; can be NorthWest, North, NorthEast, West, Center,
                    East, SouthWest, South, SouthEast (default: $GRAVITY)
    -o            - orientation of watermark in degrees (default: $ROTATION)
    -d <distance> - distance from the default location (default: $GEOMETRY)
    -s <scale>    - scale the watermark be <scale>% of destination image width (default: $SCALE)
    -r <geometry> - resize input pictures to the size defined by geometry (see ImageMagick 
                    documentation for geometry format)
    -x            - auto orient then add watermark (default is the oposite)

    files         - files to be watermarked

EOF
    exit
}

while getopts ":f:t:g:o:d:s:r:x" OPT; do
    case $OPT in
        f)
            FONT=$OPTARG
            ;;
        t)
            WATERTEXT=$OPTARG
            ;;
        g)
            GRAVITY=$OPTARG
            ;;
        o)
            ROTATION=$OPTARG
            ;;
        d)
            DISTANCE=$OPTARG
            ;;
        s)
            SCALE=$OPTARG
            ;;
        r)
            RESIZE="-resize $OPTARG"
            ;;
        x)
            ORIENT1=-auto-orient
            STRIP=-strip
            ORIENT2=
            ;;
        *)
            usage
            ;;
    esac
done

shift $(( OPTIND - 1 ))
OPTIND=1

if [[ ${#@} == 0 ]]; then
    usage
fi

makestamp()
{
    echo "Creating watermark for width=$1"
    W=$1
    convert -size "$W"x -font $FONT label:" $WATERTEXT " label.png
    H=$(identify label.png | cut -d ' ' -f 3 | cut -d 'x' -f 2)
    convert -size "$W"x$W xc:grey30 -font $FONT -pointsize $H -gravity center \
        -draw "fill grey70  rotate $ROTATION text 0,0  '$WATERTEXT'" \
        stamp_fgnd.png

    convert -size "$W"x$W xc:black -font $FONT -pointsize $H -gravity center \
        -draw "fill white  rotate $ROTATION text  1,1  '$WATERTEXT'  \
                       text  0,0  '$WATERTEXT'  \
           fill black  text -1,-1 '$WATERTEXT'" \
        +matte stamp_mask.png

    composite -compose CopyOpacity stamp_mask.png  stamp_fgnd.png  stamp.png
    mogrify  -trim +repage stamp.png
}

prev_width=''

for file in $@; do
    echo "Watermarking $file"
    bfile=$(basename $file)
    if [[ $bfile == $file ]]; then
        backup=$bfile.bak
        cp $file $backup
    else
        backup=$file
    fi
    cfile=${bfile/.*/-r.jpg}
    convert $RESIZE $ORIENT1 $backup $cfile
    width=$(identify $cfile | cut -d ' ' -f 3 | cut -d 'x' -f 1)
    width=$(( width * SCALE / 100 ))
    if [[ $prev_width != $width ]]; then
        makestamp $width
        prev_width=$width
    fi
    echo "Compositing..."
    composite -gravity $GRAVITY -geometry $GEOMETRY  stamp.png $STRIP $cfile $bfile
    if [ -n "$ORIENT2" ]; then
        echo "Reorienting..."
        convert -auto-orient -strip $bfile $bfile
    fi
    rm -f $cfile
done

rm -f stamp_fgnd.png stamp_mask.png stamp.png label.png
echo "Done"
echo
