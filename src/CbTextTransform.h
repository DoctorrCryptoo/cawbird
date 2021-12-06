/*  This file is part of Cawbird, a Gtk+ linux Twitter client forked from Corebird.
 *  Copyright (C) 2017 Timm Bäder (Corebird)
 *
 *  Cawbird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Cawbird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with cawbird.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __TEXT_TRANSFORM_H
#define __TEXT_TRANSFORM_H

#include <glib-object.h>
#include "CbTypes.h"

typedef enum {
  CB_TEXT_TRANSFORM_REMOVE_MEDIA_LINKS       = 1 << 0,
  CB_TEXT_TRANSFORM_REMOVE_TRAILING_HASHTAGS = 1 << 1,
  CB_TEXT_TRANSFORM_EXPAND_LINKS             = 1 << 2
} CbTransformFlags;



char *cb_text_transform_tweet (const CbMiniTweet *tweet,
                               guint              flags,
                               char              *quote_url);


char *cb_text_transform_text  (const char   *text,
                               CbTextEntity *entities,
                               gsize         n_entities,
                               guint         flags,
                               gsize         n_medias,
                               char         *quote_url,
                               guint         display_range_start);

char *cb_text_transform_fix_encoding (const char *text);

#endif
