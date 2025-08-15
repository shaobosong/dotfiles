#!/usr/bin/env bash
export http_proxy='socks5://$(\awk '\''$2 == "00000000" {print strtonum("0x" substr($3,7,2)) "." strtonum("0x" substr($3,5,2)) "." strtonum("0x" substr($3,3,2)) "." strtonum("0x" substr($3,1,2))}'\'' /proc/net/route):2208'
export https_proxy='socks5://$(\awk '\''$2 == "00000000" {print strtonum("0x" substr($3,7,2)) "." strtonum("0x" substr($3,5,2)) "." strtonum("0x" substr($3,3,2)) "." strtonum("0x" substr($3,1,2))}'\'' /proc/net/route):2208'
