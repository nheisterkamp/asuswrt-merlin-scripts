#!/bin/bash
sh runonrouter.sh \
   niels@ineffable \
   timemachine.sh \
     CONTINUE="yes" VERBOSITY=4 \
     AFPD_USER=\"Niels Heisterkamp\" AFPD_PASS="daemonx" \
     TIME_SHARE=true
     #INSTALL="transmission"
