" Vim plugin for completing the closest HTML or XML opening tag.
" Last Changed: 2023 Jan 16
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
:  let s:closingTagLength = 0

:  let g:immTagCoValidTagCharacterPattern = '\%(\a\|\d\|:\|_\|-\)'
:  let g:immTagCoVoidElements = ["!DOCTYPE", "area", "base", "basefont", "br",
     \ "frame", "input", "isindex", "hr", "img", "link", "meta",
     \ "nextid", "param", "plaintext", "wbr"]
:  let g:immTagCoMaxNumberOfLinesToSearch = 10
:  let g:immTagCoMaxTagTextLength = 20
:  let g:turnOffImmTagCo = 0
:  let g:immTagCoSupportedFiletypes = ["html", "xml", "js", "svelte", "vue",
     \ "jsx", "tsx", "php"]
:endfunction

" Moves the cursor to the column between the opening and closing tags.
:function immTagCo#RestoreCursor()
:  execute('normal ' . repeat('h', s:closingTagLength))
:endfunction

:function s:addAutocmdToRestoreCursor()
:  augroup immTagCoGroup
:    autocmd TextChangedI,TextChangedP
     \ *.html,*.xml,*.js,*.svelte,*.vue,*.jsx,*.tsx,*.php ++once call
     \ immTagCo#RestoreCursor()
:  augroup END
:endfunction

" Returns true if either the extension or the filetype of the current file is
" supported by the plugin:
:function s:isCurrentFileSupported()
:  let fileExtension = expand("%:e")
:  let isExtensionSupported =
     \ index(g:immTagCoSupportedFiletypes, fileExtension, 0, 1) >= 0
:  let isFiletypeSupported = index(g:immTagCoSupportedFiletypes, &filetype, 0, 1) >= 0
:  let isCurrentFileSupported = isExtensionSupported || isFiletypeSupported
:  return isCurrentFileSupported
:endfunction

" Main function, does the tag completion.
:function immTagCo#CompleteImmediateTag()
   " Stops if the plugin is turned off:
:  if g:turnOffImmTagCo
:    return
:  endif

   " Stops if both the extension and the filetype of the current file are not
   " supported by the plugin:
:  let isCurrentFileSupported = s:isCurrentFileSupported()
:  if !isCurrentFileSupported
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

   " Checks if the tag needs a closing tag:
:  let isVoidElement = index(g:immTagCoVoidElements, tagText, 0, 1) >= 0
:  if isVoidElement
:    return
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

   " Positions the cursor between the opening and closing tags:
:  let s:closingTagLength = len(tagText) + 3
:  call s:addAutocmdToRestoreCursor()

   " Restores the setting to its value at the start:
:  let &cpo = savedCpo
:endfunction

" Initializes the plugin:
:if !(exists("s:hasInitializedScript") && s:hasInitializedScript)
   " For using line continuation with backslashes:
:  let savedCpo = &cpo
:  set cpo&vim

"  Registers the appropriate functions to the events of inserting a character
:  augroup immTagCoGroup
:    autocmd!
:    autocmd InsertCharPre * call immTagCo#CompleteImmediateTag()
:  augroup END

   " Initializes variables used in the script:
:  call s:LoadScriptSettings()

:  let s:hasInitializedScript = 1

   " Restores the setting to the starting value:
:  let &cpo = savedCpo
:endif

