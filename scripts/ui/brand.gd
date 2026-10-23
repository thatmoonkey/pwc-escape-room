class_name Brand
extends RefCounted

## ONE PLACE FOR THE 2D BRAND LAYER.
##
## This milestone does not build the brand system: it only keeps every new or
## changed 2D component off the retired cyan accent and points them all at one
## source, so the PwC layer lands here in a single edit later - Orange 500 as
## the primary accent, the greys as neutrals, Georgia for headlines, body and
## SHIPMIND's voice, Arial Bold for labels and Arial for data.
##
## Rules the values already follow: orange is for key data and the primary
## action only, never a full-orange screen and never body text; the greys are
## surfaces and secondary text; nothing here is cool.
##
## The 3D station is NOT covered by this file. It keeps its own ember palette.

## Orange 500 - the future primary accent.
const ACCENT := Color(0.992157, 0.317647, 0.031373)
## #FE7C39 - the accent's lighter tint, for a selected state rather than a call
## to action.
const ACCENT_TINT := Color(0.996078, 0.486275, 0.223529)
## The dark surface a panel sits on. Near-black, warm-neutral, never pure black.
const SURFACE := Color(0.078431, 0.078431, 0.086275)
const SURFACE_RAISED := Color(0.129412, 0.133333, 0.145098)
## #F5F7F8 - primary text on a dark surface.
const INK := Color(0.960784, 0.968627, 0.972549)
## #DFE3E6 - dividers, quiet rules and secondary labels.
const NEUTRAL_LIGHT := Color(0.874510, 0.890196, 0.901961)
## #A1A8B3 - the quiet tone: a note that is not a warning.
const NEUTRAL := Color(0.631373, 0.658824, 0.701961)

## The type scale, in pixels. Sizes only for now: the families (Georgia for
## headlines, body and SHIPMIND's voice, Arial Bold for sub-heads and labels,
## Arial for data) belong to the brand layer and land here with it.
const SIZE_TITLE := 20
const SIZE_DATA := 16
const SIZE_LABEL := 15
const SIZE_SMALL := 13

## The terminal's readout body, one step under the data size. A decision screen
## prints a long readout and then stacks eleven choices under it, so the body
## size is set where the copy still reads and the whole screen still fits.
const SIZE_BODY := 15
## A choice button's own text, one step under that again, for the same reason.
const SIZE_COMPACT := 14
