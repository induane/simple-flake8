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
    errors.push {
      "message": "Unable to get report, please check flake8 bin path",
      "evidence": flake8Path,
      "position": 1,
      "line": 1
    }
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
        errors.push {
          "message": "flake8 is crashing, please check flake8 bin path or reinstall flake8",
          "evidence": flake8Path,
          "position": 1,
          "line": 1
        }
      callback errors

module.exports =

  configDefaults:
    flake8Path: "/usr/bin/flake8"
    ignoreErrors: ""
    mcCabeComplexityThreshold: ""
    validateOnSave: true

class SimpleFlake8View extends SelectListView
  @activate: ->
    new SimpleFlake8View

  keyBindings: null

  initialize: ->
    super

    @addClass('simple-flake8 overlay from-top')
    atom.workspaceView.command 'simple-flake8:toggle', => @toggle()

  getFilterKey: ->
    'eventDescription'

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

    if @previouslyFocusedElement[0] and @previouslyFocusedElement[0] isnt document.body
      @eventElement = @previouslyFocusedElement
    else
      @eventElement = atom.workspaceView
    @keyBindings = atom.keymap.findKeyBindings(target: @eventElement[0])

    filePath = editor.getPath()

    flake filePath, (errors) ->
      if errors.length == 0
        return
      else
        errors = []
        for error in errors:
          if error.type
            message = error.type + " " + error.message
          else
            message = error.message
          errors.push({message, error})
        @setItems(errors)

    # events = []
    # for eventName, eventDescription of _.extend($(window).events(), @eventElement.events())
    #   events.push({eventName, eventDescription}) if eventDescription
    # events = _.sortBy(events, 'eventDescription')
    # @setItems(events)

    atom.workspaceView.append(this)
    @focusFilterEditor()

  viewForItem: ({eventName, eventDescription}) ->
    keyBindings = @keyBindings
    $$ ->
      @li class: 'event', 'data-event-name': eventName, =>
        @div class: 'pull-right', =>
          for binding in keyBindings when binding.command is eventName
            @kbd _.humanizeKeystroke(binding.keystrokes), class: 'key-binding'
        @span eventDescription, title: eventName

  confirmed: ({eventName}) ->
    @cancel()
    @eventElement.trigger(eventName)
