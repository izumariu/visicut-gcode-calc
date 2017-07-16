#!/usr/bin/awk -f

#############
# FUNCTIONS #
#############

function i_mm(i) { # inches to millimeters
	return (i*25.4)
}

function hypotenuse(x,y) {
	if (x<0) x_abs=-x ;else x_abs=x
	if (y<0) y_abs=-y ;else y_abs=y
	return sqrt(x_abs^2+y_abs^2)
}

function getattr(a) { # important function! get a parameter of the command
	spos = match( $0, toupper(a) "[0-9.]+" ) # find the position of the desired parameter
	ssub = substr( $0, spos+1 ) # save the substring
	if( ssub ~ /[ \t]|[A-Z]/ ) { # is there more that needs to be cut off?
		ssub = substr( ssub, 1, match( ssub, /[ \t]|[A-Z]/ ) - 1 ) # then do so
	}
	return ssub
}

function duration(l,fr) { # params: length and feed rate => seconds
	return (l/fr)*(100/speed) # ... do we really need a function for that?
}

function getCommencedMinutes() {
	if((sprintf("%i",tt_duration*(100/speed))/60)%1==0) {
		if(sprintf("%i",tt_duration*(100/speed)/60)==0) {
			return 1;
		} else {
			return sprintf("%i",tt_duration*(100/speed)/60)
		}
	} else {
		return (sprintf("%i",tt_duration*(100/speed)/60)+1)
	}
}

####################
# CONDITION BLOCKS #
####################

BEGIN {

	if(length(ARGV)!=2) {
		print "USAGE: awk -f visicut-gcode.awk <GCODE_FILE>"
		haserrs = 1
		exit(1)
	}

	if(s) {
		speed = s
	} else {
		speed = 100
	}
	print "Speed: " speed "%"
	mode_l = "m"
	mode_c = "a"
}

##################
# - FOR SETTINGS #
##################

/^G20[^0-9]/ {
	print "Entering inch mode on line " NR "."
	mode_l = "i"
}

/^G21[^0-9]/ {
	print "Entering millimeter mode on line " NR "."
	mode_l = "m"
}

/^G90[^0-9]/ {
	print "Entering absolute coordinate mode on line " NR "."
	mode_c = "a"
}

/^G91[^0-9]/ {
	print "Entering relative coordinate mode on line " NR "."
	mode_c = "r"
}

#################
# - FOR MOTIONS #
#################

/^G0[^0-9]/ { # movement with laser off, used for positioning
	if(!fr_g0) { # if feed rate not specified
		if( $0 ~ /F[0-9\.]+/ ) { # is there a feed rate specified in the command?
			fr_g0 = getattr("f")
			if(mode_l=="i") { # inches?!
				fr_g0 = i_mm(fr_g0) # convert it, the f***!
			}
		} else {
			print "FATAL(" NR "): G0 with no feed rate"
			haserrs = 1
			exit(1)
		}
	}

	# calculate motions!
	x_g = getattr("x")
	y_g = getattr("y")
	if(!x_p) x_p=x_g # if previous x value not set, set it
	if(!y_p) y_p=y_g # same as above for y
	mv_length = hypotenuse( x_p - x_g , y_p - y_g )
	tt_length+= mv_length
	tt_duration += duration(mv_length,fr_g0)
	posset = 1 # for a g1 warning (starting position unknown)

}

/^G1[^0-9]/ { # movement with laser on
	if(!fr_g1) { # if feed rate not specified
		if( $0 ~ /F[0-9\.]+/ ) { # is there a feed rate specified in the command?
			fr_g1 = getattr("f")
			if(mode_l=="i") { # inches?!
				fr_g1 = i_mm(fr_g1) # convert it, the f***!
			}
			#print("G1 feed rate set to " fr_g1 " mm/m on line " NR ".")
		} else {
			print "FATAL(" NR "): G1 with no feed rate"
			haserrs = 1
			exit(1)
		}
	}

	if(!posset) { # was g0 used before?
		print "WARNING: G1 used before positioning with G0 occured!"
		print "WARNING: Starting position unknown!"
	}
	# calculate motions!
	x_g = getattr("x")
	y_g = getattr("y")
	if(!x_p) x_p=x_g # if previous x value not set, set it
	if(!y_p) y_p=y_g # same as above for y
	mv_length = hypotenuse( x_p - x_g , y_p - y_g )
	tt_length+= mv_length
	tt_duration += duration(mv_length,fr_g1)
	#exit
}

###########
# RESULTS #
###########

END {
	if(!haserrs) {

		print ""
		print "###########"
		print "# RESULTS #"
		print "###########"
		#print ""
		if(NR==1) print("Parsed " NR " line.") ;else print("Parsed " NR " lines.")
		print "Total length of path: " sprintf("%.2f",tt_length) " mm"
		#print "Variable holding the minutes: " sprintf("%.2f",tt_duration)
		print "Commenced minutes: " getCommencedMinutes()
		print "Resulting price: " sprintf("€ %.2f",(getCommencedMinutes()*0.15))
		#print "fr_g0: " fr_g0
		#print "fr_g1: " fr_g1

	}
}
