_ = require 'underscore-plus'
process = require 'child_process'
byline = require 'byline'
fs = require 'fs'
{$, $$, SelectListView} = require 'atom'

flake = (filePath, callback) ->
  line_expr = /:(\d+):(\d+): ([CEFW]\d{3}) (.*)/
  errors = []
  currentIndex = -1
  skipLine = false

  params = ["--show-source", filePath]
  ignoreErrors = atom.config.get "flake8.ignoreErrors"
  mcCabeComplexityThreshold = atom.config.get "flake8.mcCabeComplexityThreshold"
  flake8Path = atom.config.get "flake8.flake8Path"

  if not fs.existsSync(flake8Path)
    console.log("Unable to get report, please check flake8 bin path")
    callback errors
    return

  if not not ignoreErrors
    params.push("--ignore=#{ ignoreErrors }")

  if not not mcCabeComplexityThreshold
    params.push("--max-complexity=#{ mcCabeComplexityThreshold }")

  proc = process.spawn flake8Path, params

  # Watch for flake8 errors
  output = byline(proc.stdout)
  output.on 'data', (line) =>
    line = line.toString().replace filePath, ""
    matches = line_expr.exec(line)

    if matches
      [_, line, position, type, message] = matches

      errors.push {
        "message": message,
        "type": type,
        "position": parseInt(position),
        "line": parseInt(line)
      }
      currentIndex += 1
      skipLine = false
    else
      if not skipLine
        errors[currentIndex].evidence = line.toString().trim()
        skipLine = true

  # Watch for the exit code
  proc.on 'exit', (exit_code, signal) ->
    if exit_code == 1 and errors.length == 0
      console.log('Flake8 is crashing. Check flake8 bin path.')
    callback errors

module.exports =


class SimpleFlake8View extends SelectListView

  configDefaults:
    flake8Path: "/usr/bin/flake8"
    ignoreErrors: ""
    mcCabeComplexityThreshold: ""
    validateOnSave: true

  @activate: ->
    new SimpleFlake8View

  keyBindings: null

  initialize: ->
    super

    @addClass('simple-flake8 overlay from-top')
    atom.workspaceView.command 'simple-flake8:toggle', => @toggle()

  getFilterKey: ->
    'message'

  toggle: ->
    if @hasParent()
      @cancel()
    else
      @attach()

  attach: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?
    return unless editor.getGrammar().name == 'Python'

    @storeFocusedElement()
    filePath = editor.getPath()

    @setLoading('Running Flake8 Lint...')
    atom.workspaceView.append(this)
    @focusFilterEditor()

    flake filePath, (errors) =>
      error_list = []
      if errors.length == 0
        return

      for error in errors
        if error.type
          message = error.line + ' - ' + error.type + " " + error.message
        else
          message = error.message
        # console.log(message)
        error_list.push({message, error})

      @setItems(error_list)

    if @previouslyFocusedElement[0] and @previouslyFocusedElement[0] isnt document.body
      @eventElement = @previouslyFocusedElement
    else
      @eventElement = atom.workspaceView

  viewForItem: ({message, error}) ->
    console.log('Processing: ' + message)
    # data = '<li class="event"><div class="pull-right"></div><span title="error">' + message + '</span></li>'
    # console.log('Returning html: ' + data)
    # return data
    base_msg = error.type + ' - ' + error.message
    $$ ->
      @li class: 'event', 'data-event-name': error.type, =>
        @div class: 'pull-right', =>
            # Use the keybinding class to display line numbers
            @kbd "Line: " + error.line, class: 'key-binding'
        @span base_msg[0..65], title: message

  confirmed: ({eventName}) ->
    @cancel()
    @eventElement.trigger(eventName)
