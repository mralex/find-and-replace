{_} = require 'atom'
{Emitter} = require 'emissary'

module.exports =
class ResultsModel
  Emitter.includeInto(this)

  constructor: (state={}) ->
    @useRegex = state.useRegex ? false
    @caseSensitive = state.caseSensitive ? false

    rootView.eachEditSession (editSession) =>
      editSession.on 'contents-modified', => @onContentsModified(editSession)

    @clear()

  serialize: ->
    {@useRegex, @caseSensitive}

  clear: ->
    @pathCount = 0
    @matchCount = 0
    @regex = null
    @results = {}
    @paths = []
    @active = false
    @emit('cleared')

  search: (pattern, paths)->
    @active = true
    @regex = @getRegex(pattern)

    onPathsSearched = (numberOfPathsSearched) =>
      @emit('paths-searched', numberOfPathsSearched)

    promise = project.scan @regex, {paths, onPathsSearched}, (result) =>
      @setResult(result.filePath, result.matches)

    promise.done => @emit('finished-searching')
    promise

  toggleUseRegex: ->
    @useRegex = not @useRegex

  toggleCaseSensitive: ->
    @caseSensitive = not @caseSensitive

  getPathCount: ->
    @pathCount

  getMatchCount: ->
    @matchCount

  getPaths: (filePath) ->
    @paths

  getResult: (filePath) ->
    @results[filePath]

  setResult: (filePath, matches) ->
    if matches and matches.length
      @addResult(filePath, matches)
    else
      @removeResult(filePath)

  addResult: (filePath, matches) ->
    if @results[filePath]
      @matchCount -= @results[filePath].length
    else
      @pathCount++
      @paths.push(filePath)

    @matchCount += matches.length

    @results[filePath] = matches
    @emit('result-added', filePath, matches)

  removeResult: (filePath) ->
    if @results[filePath]
      @pathCount--
      @matchCount -= @results[filePath].length

      @paths = _.without(@paths, filePath)
      delete @results[filePath]
      @emit('result-removed', filePath)

  getRegex: (pattern) ->
    flags = 'g'
    flags += 'i' unless @caseSensitive

    if @useRegex
      new RegExp(pattern, flags)
    else
      new RegExp(_.escapeRegExp(pattern), flags)

  onContentsModified: (editSession) =>
    return unless @active

    matches = []
    editSession.scan @regex, (match) ->
      matches.push(match)

    @setResult(editSession.getPath(), matches)
    @emit('finished-searching')
