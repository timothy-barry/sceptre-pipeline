-- Keep reference tables readable without widening the page on small screens.
-- A named, focusable region supports keyboard horizontal scrolling.
function Table(el)
  return pandoc.Div({el}, pandoc.Attr('', {'table-scroll'}, {
    {'role', 'region'},
    {'aria-label', 'Scrollable reference table'},
    {'tabindex', '0'}
  }))
end
