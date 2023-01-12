" Vim plugin for completing the closest HTML or XML opening tag.
" Last Changed: 2022 Jan 01
" Maintainer: Victor S.
" License: This file is placed in the public domain.

:function s:InsertClosingTag(tagText)
:  let closingTagText = "></" . a:tagText . ">"
:  let v:char = closingTagText
:endfunction

:function s:SearchClosingCharacter(tagLine)
:  let closingCharacterPattern = '[>/]'

   " Searches backward, counts the cursor column, does not move the
   " cursor, does not wrap around the file borders.
:  let flags = "bcnW"

:  let limitLine = a:tagLine

:  let [closingCharacterLine, closingCharacterColumn] =
     \ searchpos(
     \   closingCharacterPattern,
     \   flags,
     \   limitLine
     \ )

:  return [closingCharacterLine, closingCharacterColumn]
:endfunction

" Gets the characters that compose the tag name:
:function s:ReadTagText(tagLine, tagStartColumn, validTagCharacterPattern)
:  let tagText = ""
:  let hasReadWholeTagText = 0
:  let lineContent = getline(a:tagLine)
:  let columnOffset = 0

   " Collects the text of the tag:
:  while !hasReadWholeTagText
:    let byteColumn = a:tagStartColumn + columnOffset
:    let byteIndex = byteColumn - 1
:    let currentCharacter = strpart(lineContent, byteIndex, 1, 0)

:    let hasValidTagTextCharacter =
       \ currentCharacter =~? a:validTagCharacterPattern

:    if hasValidTagTextCharacter
:      let tagText = tagText . currentCharacter
:    else
:      let hasReadWholeTagText = 1
:      break
:    endif

:    let columnOffset = columnOffset + 1
:  endwhile
:  return tagText
:endfunction

" Searches for the position of the closest opening tag:
:function s:SearchImmediateOpeningTag(
   \   validTagCharacterPattern,
   \   maxTagTextLength,
   \   cursorStartLine,
   \   maxNumberOfLinesToSearch
   \ )
:  let openingTagPattern = '<\zs' . a:validTagCharacterPattern
     \ . '\{1,' . a:maxTagTextLength . '}'

   " Search backwards, counts the cursor column, does not move the cursor,
   " and does not travel around the file borders.
:  let flags = "bcnW"

   " Searches only a small amount of previous lines to increase speed and to
   " account for tags spreaded over many lines:
:  let limitLineToSearch = max([
     \   1,
     \   (a:cursorStartLine - a:maxNumberOfLinesToSearch)
     \ ])

:  let [tagLine, tagColumn] = searchpos(
     \   openingTagPattern,
     \   flags,
     \   limitLineToSearch
     \ )

:  return [tagLine, tagColumn]
:endfunction

" Saves settings into global variables to allow modifications by the user:
:function s:LoadScriptSettings()
:  let s:hasToMoveCursorAfterOpeningTag = 0
:  let s:lastTagLength = 0

:  let g:immTagCoValidTagCharacterPattern = '\%(\a\|\d\|:\|_\|-\)'
:  let g:immTagCoVoidElements = ["!DOCTYPE", "area", "base", "basefont", "br",
     \ "frame", "input", "isindex", "hr", "img", "link", "meta",
     \ "nextid", "param", "plaintext", "wbr"]
:  let g:immTagCoMaxNumberOfLinesToSearch = 10
:  let g:immTagCoMaxTagTextLength = 20
:endfunction

:function immTagCo#saveUseOfHtmlInBuffer()
   " Saves in a buffer variable if the file being edited is in HTML format:
:  if !exists("b:isUsingHtmlSyntax")
:    let b:isUsingHtmlSyntax = (
       \ &filetype =~? '\%(html\|xml\|svelte\|vue\|jsx\|tsx\|php\)')
:  endif
:endfunction

" Main function, does the tag completion.
:function immTagCo#CompleteImmediateTag()
   " Stops if the plugin is turned off:
:  if (exists("g:turnOffImmTagCo") && g:turnOffImmTagCo)
:    return
:  endif

   " Stops if the last inserted character is not a closing character:
:  let isClosingCharacter = v:char ==? ">"
:  if !isClosingCharacter
:    return
:  endif

   " Setting for allowing line continuation:
:  let savedCpo = &cpo
:  set cpo&vim

   " Records the the position of the cursor at the start of the script:
:  let cursorStartLine = line(".")
:  let cursorStartColumn = col(".")

   " Searches for the position of the closest opening tag:
:  let [tagLine, tagColumn] = s:SearchImmediateOpeningTag(
     \   g:immTagCoValidTagCharacterPattern,
     \   g:immTagCoMaxTagTextLength,
     \   cursorStartLine,
     \   g:immTagCoMaxNumberOfLinesToSearch
     \ )

   " Stops if no valid tag was found:
:  if (tagLine == 0 || tagColumn == 0)
:    return
:  endif

   " Reads the text of the closest opening tag:
:  let tagText = s:ReadTagText(
     \   tagLine,
     \   tagColumn,
     \   g:immTagCoValidTagCharacterPattern
     \ )

   " Saves in a buffer variable if the file being edited is of HTML type:
:  s:immTagCo#storeUseOfHtmlInBuffer()

   " Checks if the tag needs a closing tag:
:  if b:isUsingHtmlSyntax
:    let isVoidElement = index(g:immTagCoVoidElements, tagText, 0, 1) >= 0
:    if isVoidElement
:      return
:    endif
:  endif

   " Searches for the position of the closing angle bracket of the closest
   " opening tag:
:  let [closingCharacterLine, closingCharacterColumn] =
     \ s:SearchClosingCharacter(tagLine)

   " Stops if the tag being completed already has a closing tag:
:  let isClosingCharacterAfterTag = (closingCharacterLine > tagLine
     \ || (closingCharacterLine == tagLine
     \ && closingCharacterColumn >= tagColumn))

:  if isClosingCharacterAfterTag
:    return
:  endif

   " Inserts the closing tag of the closest opening tag:
:  call s:InsertClosingTag(tagText)

   " Information used to position the cursor after the opening tag:
:  let s:hasToMoveCursorAfterOpeningTag = 1
:  let s:lastTagLength = len(tagText) + 3

   " Restores the setting to its value at the start:
:  let &cpo = savedCpo
:endfunction

" Moves the cursor to the column between the opening and closing tags.
:function immTagCo#RestoreCursor()
:  if !s:hasToMoveCursorAfterOpeningTag
:    return
:  endif

:  execute('normal ' . repeat('h', s:lastTagLength))

:  let s:hasToMoveCursorAfterOpeningTag = 0
:  let s:lastTagLength = 0
:endfunction

" Initializes the plugin:
:if !(exists("s:hasInitializedScript") && s:hasInitializedScript)
   " For using line continuation with backslashes:
:  let savedCpo = &cpo
:  set cpo&vim

"  Registers the appropriate functions to the events of inserting a character
:  augroup immTagCoGroup
:    autocmd!
:    autocmd InsertCharPre *.html,*.xml,*.js,*.svelte,*.vue,*.jsx,*.tsx,*.php
       \ call immTagCo#CompleteImmediateTag()
:    autocmd TextChangedI,TextChangedP 
       \ *.html,*.xml,*.js,*.svelte,*.vue,*.jsx,*.tsx,*.php call
       \ immTagCo#RestoreCursor()
:  augroup END

   " Initializes variables used in the script:
:  call s:LoadScriptSettings()

:  let s:hasInitializedScript = 1

   " Restores the setting to the starting value:
:  let &cpo = savedCpo
:endif

