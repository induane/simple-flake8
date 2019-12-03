/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS104: Avoid inline assignments
 * DS204: Change includes calls to have a more natural evaluation order
 * DS206: Consider reworking classes to avoid initClass
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
let SimpleFlake8View;
let _ = require('underscore-plus');
const process = require('child_process');
const byline = require('byline');
const {SelectListView, $, $$} = require('atom-space-pen-views');

// Basic flake8 parsing tool with callback functionality
const flake = function(filePath, callback) {
  const line_expr = /:(\d+):(\d+): ([A-Z]\d{3}) (.*)/;
  const errors = [];
  let currentIndex = -1;
  let skip_line = false;

  const params = ["--show-source", filePath];
  const ignoreErrors = atom.config.get("simple-flake8.ignoreErrors");
  const mcCabeComplexityThreshold = atom.config.get("simple-flake8.mcCabeComplexityThreshold");
  const flake8cmd = atom.config.get("simple-flake8.flake8Command");
  const flake8params = atom.config.get("simple-flake8.cmdLineArguments");
  console.log(flake8cmd);
  if (ignoreErrors) {
    params.push(`--ignore=${ ignoreErrors }`);
  }

  if (mcCabeComplexityThreshold) {
    params.push(`--max-complexity=${ mcCabeComplexityThreshold }`);
  }

  if (flake8params) {
    params.push(flake8params);
  }

  const proc = process.spawn(flake8cmd, params);

  // Watch for flake8 errors
  const output = byline(proc.stdout);
  output.on('data', line => {
    line = line.toString().replace(filePath, "");
    const matches = line_expr.exec(line);

    if (matches) {
      let message, position, type;
      [_, line, position, type, message] = Array.from(matches);

      errors.push({
        "message": message,
        "type": type,
        "position": parseInt(position),
        "line": parseInt(line)
      });
      currentIndex += 1;
      return skip_line = false;
    } else {
      if (!skip_line) {
        try {
          errors[currentIndex].evidence = line.toString().trim();
        } catch (error) {
          console.log(error);
        }
        return skip_line = true;
      }
    }
  });

  // Watch for the exit code
  return proc.on('exit', function(exit_code, signal) {
    if ((exit_code === 1) && (errors.length === 0)) {
      console.log('Flake8 crashed or is unavailable. Check command path.');
    }
    return callback(errors);
  });
};

module.exports =
(SimpleFlake8View = (function() {
  SimpleFlake8View = class SimpleFlake8View extends SelectListView {
    static initClass() {
      this.prototype.keyBindings = null;
      this.prototype.config = {
        flake8Command: {
          type: "string",
          default: "flake8"
        },
        ignoreErrors: {
          type: "boolean",
          default: false
        },
        mcCabeComplexityThreshold: {
          type: "string",
          default: ""
        },
        cmdLineArguments: {
          type: "string",
          default: ""
        },
        validateOnSave: {
          type: "boolean",
          default: true
        }
      };
    }

    static activate() {
      const view = new SimpleFlake8View;
      return this.disposable = atom.commands.add('atom-workspace', 'simple-flake8:toggle', () => view.toggle());
    }

    static deactivate() {
      return this.disposable.dispose();
    }

    activate() {
      atom.commands.add('atom-text-editor', 'simple-flake8:toggle', () => this.toggle());
      return atom.commands.add('atom-text-editor', 'core:save', () => {
        const on_save = atom.config.get("simple-flake8.validateOnSave");
        if (on_save === true) {
          return this.toggle();
        }
      });
    }

    initialize() {
      super.initialize(...arguments);
      return this.addClass('simple-flake8');
    }


    getFilterKey() {
      return 'message';
    }

    cancelled() { return this.hide(); }

    toggle() {
      if ((this.panel != null ? this.panel.isVisible() : undefined)) {
        return this.cancel();
      } else {
        return this.show();
      }
    }

    show() {
      // Get out of here unless this is a python file
      let needle;
      const editor = atom.workspace.getActiveTextEditor();
      if (editor == null) { return; }
      if ((needle = editor.getGrammar().name, !['Python', 'MagicPython'].includes(needle))) { return; }

      if (this.panel == null) { this.panel = atom.workspace.addModalPanel({item: this}); }
      this.panel.show();

      this.storeFocusedElement();
      this.setLoading('Running Flake8 Linter...');

      if (this.previouslyFocusedElement[0] && (this.previouslyFocusedElement[0] !== document.body)) {
        this.eventElement = this.previouslyFocusedElement[0];
      } else {
        this.eventElement = atom.views.getView(atom.workspace);
      }

      const filePath = editor.getPath();
      console.log(filePath);
      flake(filePath, errors => {
        const error_list = [];
        if (errors.length === 0) {
          this.cancel();
          return;
        }

        for (let error of Array.from(errors)) {
          var message;
          if (error.type) {
            message = error.line + ' - ' + error.type + " " + error.message;
          } else {
            ({
              message
            } = error);
          }
          error_list.push(error);
        }
        return this.setItems(error_list);
      });

      return this.focusFilterEditor();
    }

    hide() {
      return (this.panel != null ? this.panel.hide() : undefined);
    }

    viewForItem(error) {
      let base_msg;
      if (error.type) {
        base_msg = error.type + ' - ' + error.message;
      } else {
        base_msg = error.message;
      }
      return $$(function() {
        return this.li({class: 'event', 'data-event-name': error.type}, () => {
          this.div({class: 'pull-right'}, () => {
              // Use the keybinding class to display line numbers
              return this.kbd("Line: " + error.line, {class: 'key-binding'});
          });
          return this.span(base_msg.slice(0, 66), {title: error.message});
        });
      });
    }

    confirmed(error) {
      this.cancel();
      if (error) {
        let options;
        const editor = atom.workspace.getActiveTextEditor();

        // Go to line -1 due to differencing in indexing
        return editor.cursors[0].setBufferPosition(
          [error.line - 1, error.position - 1],
          (options={'autoscroll': true})
        );
      }
    }
  };
  SimpleFlake8View.initClass();
  return SimpleFlake8View;
})());


module.exports = new SimpleFlake8View();
