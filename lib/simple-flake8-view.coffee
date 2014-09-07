_ = require 'underscore-plus'
process = require 'child_process'
byline = require 'byline'
{$, $$, SelectListView} = require 'atom'

# Basic flake8 parsing tool with callback functionality
flake = (filePath, callback) ->
  line_expr = /:(\d+):(\d+): ([CEFW]\d{3}) (.*)/
  errors = []
  currentIndex = -1
  skip_line = false

  params = ["--show-source", filePath]
  ignoreErrors = atom.config.get "simple-flake8.ignoreErrors"
  mcCabeComplexityThreshold = atom.config.get "simple-flake8.mcCabeComplexityThreshold"
  flake8cmd = atom.config.get "simple-flake8.flake8Command"

  if not not ignoreErrors
    params.push("--ignore=#{ ignoreErrors }")

  if not not mcCabeComplexityThreshold
    params.push("--max-complexity=#{ mcCabeComplexityThreshold }")

  proc = process.spawn flake8cmd, params

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
      skip_line = false
    else
      if not skip_line
        errors[currentIndex].evidence = line.toString().trim()
        skip_line = true

  # Watch for the exit code
  proc.on 'exit', (exit_code, signal) ->
    if exit_code == 1 and errors.length == 0
      console.log('Flake8 crashed or is unavailable. Check command path.')
    callback errors


class SimpleFlake8View extends SelectListView

  configDefaults:
    flake8Command: "flake8"
    ignoreErrors: ""
    mcCabeComplexityThreshold: ""
    validateOnSave: true

  @activate: ->
    new SimpleFlake8View

  activate: (state) ->
    atom.workspaceView.command 'simple-flake8:toggle', => @toggle()
    atom.workspaceView.command 'core:save', =>
      on_save = atom.config.get "simple-flake8.validateOnSave"
      if on_save == true
        @toggle()

  initialize: ->
    super
    @addClass('simple-flake8 overlay from-top')

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

    filePath = editor.getPath()

    @setLoading('Running Flake8 Linter...')
    atom.workspaceView.append(this)
    @focusFilterEditor()

    flake filePath, (errors) =>
      error_list = []
      if errors.length == 0
        @cancel()
        return

      for error in errors
        if error.type
          message = error.line + ' - ' + error.type + " " + error.message
        else
          message = error.message
        error_list.push(error)
      @setItems(error_list)

  viewForItem: (error) ->
    if error.type
      base_msg = error.type + ' - ' + error.message
    else
      base_msg = error.message
    $$ ->
      @li class: 'event', 'data-event-name': error.type, =>
        @div class: 'pull-right', =>
            # Use the keybinding class to display line numbers
            @kbd "Line: " + error.line, class: 'key-binding'
        @span base_msg[0..65], title: error.message

  confirmed: (error) ->
    @cancel()
    if error
      editor = atom.workspace.getActiveEditor()

      # Go to line -1 due to differencing in indexing
      editor.cursors[0].setBufferPosition(
        [error.line - 1, error.position -1],
        options={'autoscroll': true}
      )


module.exports = new SimpleFlake8View()
