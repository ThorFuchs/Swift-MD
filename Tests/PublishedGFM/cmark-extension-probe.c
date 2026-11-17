// SPDX-License-Identifier: Apache-2.0
// Demonstrate the pinned parser's inline-hook precedence, not every possible API.
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "cmark-gfm.h"
#include "cmark-gfm-extension_api.h"

static int ampersands, angles, controls;

static cmark_node *observe(cmark_syntax_extension *extension, cmark_parser *parser,
                           cmark_node *parent, unsigned char character,
                           cmark_inline_parser *inline_parser) {
  (void)extension; (void)parser; (void)parent; (void)inline_parser;
  if (character == '&') ++ampersands;
  if (character == '<') ++angles;
  if (character == 'Z') ++controls;
  return NULL;
}

int main(void) {
  cmark_mem *allocator = cmark_get_default_mem_allocator();
  cmark_syntax_extension *extension = cmark_syntax_extension_new("observe");
  cmark_llist *characters = NULL;
  characters = cmark_llist_append(allocator, characters, (void *)(uintptr_t)'&');
  characters = cmark_llist_append(allocator, characters, (void *)(uintptr_t)'<');
  characters = cmark_llist_append(allocator, characters, (void *)(uintptr_t)'Z');
  cmark_syntax_extension_set_special_inline_chars(extension, characters);
  cmark_syntax_extension_set_match_inline_func(extension, observe);
  cmark_parser *parser = cmark_parser_new(CMARK_OPT_DEFAULT);
  if (!cmark_parser_attach_syntax_extension(parser, extension)) return 2;
  const char *source = "plain Z &#12345678; <!--> trailing\n";
  cmark_parser_feed(parser, source, strlen(source));
  cmark_node *root = cmark_parser_finish(parser);
  if (!root) return 3;
  printf("observed: Z=%d ampersand=%d less-than=%d\n", controls, ampersands, angles);
  cmark_node_free(root);
  cmark_parser_free(parser);
  cmark_syntax_extension_free(allocator, extension);
  return !(controls == 1 && ampersands == 0 && angles == 0);
}
