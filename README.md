# Misc-ReShade-Shaders
Various ReShade shaders I've made/ported

## AppleIIPixels.fx

A shader to emulate Apple II color rendering technique (use with a second NTSC decode shader pass like NTSCDEcoder.fx)

## BRDF.fx

Adds a BRDF specular to screenspace normals

## CRT-Lottes.fx

A variant of Lottes with the option to rotate the pixel masks 90 degrees

## DesaturateDepth.fx

Desaturation fog filter using the depth buffer

## Signal.fx

A shader that applies a per-channel signal distortion-esque effect. Also contains a tweaked chromatic abberation effect.

## Loose-Connection.fx

A port of the VHS tape shader from the RetroArch NTSC shader package

## NTSC.fx

A port of the NTSC shader from RetroArch

## NTSCDecoder.fx

Implemntation of https://www.shadertoy.com/view/Mdffz7 to emulate decoding of composite video signals (best used after AppleIIPixels.fx)

## retroshader.fx

Port of Indecom's "Retro FX with Dither" shader for GZDoom, with some minor tweaks
