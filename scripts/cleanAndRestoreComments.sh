#!/bin/bash
#
#
# Synopsis :
#     Clean and restore comments in music files with beets.
#
# Usage: bash ./cleanAndRestoreComments.sh

# History
# Date            Version        Auteur        Commentaire
# 16/07/2017      1.0            Djhibee       Creation
#
# External dependencies:
    source ${BASH_SOURCE%/*}/../SETTINGS
    source ${BASH_SOURCE%/*}/utils.sh

beet -c $CONFIG_LOSSY modify -M -y comments=""
beet -c $CONFIG_LOSSLESS modify -M -y comments=""

beet -c $CONFIG_LOSSY modify -M -y  albumartist:"AC/DC" album:"Fly on the Wall" comments="1985 Atlantic 81263-1-E Original US Pressing, "
beet -c $CONFIG_LOSSY modify -M -y  albumartist:"AC/DC" album:"Stiff upper Lip" comments="bootleg, 7559-62494-1, Sony 180g LP (2003); Mastered by George Marino @ Sterling Sound, NYC, Sony 180g LP (2003); "
beet -c $CONFIG_LOSSY modify -M -y  album:"51 bandes originales pour 51 Films" comments="Label : Larghetto - Abeille Musique"
beet -c $CONFIG_LOSSY modify -M -y  albumartist:"OMI" album:"Me 4 U" comments="88875 15383 2 ,"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"Bob Dylan" album:"Highway 61 Revisited" comments="24bit/96khz Vinyl Rip, "
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"Antonín Dvořák; Berlin Philharmonic String Quintet" album:"String Quintet in G, op. 77 / Nocturne, op. 40 / String Quintet in E-flat, op. 97" comments="5.0 Multi Channel version"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"OMI" album:"Me 4 U" comments="88875 15383 2"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"Norah Jones" album:"The Collection" comments="Analogue Productions ‎– The Collection"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"Louise Attaque" album:"Louise attaque" comments="Athmosphériques 067507-2, FLAC 1.2.1. -8"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"George Michael" album:"Older" comments="CRC : 28D901B1, CRC : 3B516873, CRC : 441283FC, CRC : 49DA6DBBCRC : 82BE3966, CRC : B61B1D49, CRC : C4310B71, CRC : EEFE5DDC"
beet -c $CONFIG_LOSSLESS modify -M -y  album:"Pleasure and Pain" comments="24bit/96khz Vinyl Rip, "
beet -c $CONFIG_LOSSLESS modify -M -y  album:"Le Meilleur de Jacques Dutronc" comments="Disques Vogue / BMG France / 74321754562"
beet -c $CONFIG_LOSSLESS modify -M -y  album:"Rocky III: Original Motion Picture Score" comments="EMI America CDP7 46561 2"
beet -c $CONFIG_LOSSLESS modify -M -y  album:"Hold On, We're Going Home" comments="Interprètes : Drake, Main Artist; Majid Jordan, Featured Artist; A Graham, Author, Composer; M. Maskati, Author, Composer; J. Ullman, Composer, Author; P. Jeffries, Author, Composer; N. Shebib, Author, Composer"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"Ludwig van Beethoven; Maria João Pires, London Symphony Orchestra, Bernard Haitink" album:"Piano Concerto no. 2" comments="LSO0245 BEETHOVEN Piano Concerto No 2_24bit 96kHz FLAC"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"Hector Berlioz; Valery Gergiev, London Symphony Orchestra" album:"Roméo et Juliette" comments="LSO0762 BERLIOZ Roméo et Juliette 24bit 96kHz FLAC"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"Valery Gergiev, London Symphony Orchestra" album:"RACHMANINOV Symphony No 1 & BALAKIREV Tamara" comments="LSO0784 RACHMANINOV Symphony No 1 & BALAKIREV Tamara 24bit 96kHz FLAC"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"AC/DC" album:"The Razors Edge" comments="Sony 180g LP (2003); Mastered by George Marino @ Sterling Sound, NYC"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"Eddie Vedder" album:"Into the Wild" comments="24bit/96khz Vinyl Rip, "
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"The Beatles" album:"Mono Masters" comments="The Beatles in Mono - 2014 Remaster - Apple 5099963379716"
beet -c $CONFIG_LOSSLESS modify -M -y  albumartist:"IZIA" album:"IZIA" comments="freedbID : 9C0CCF0D"
