Levels = require "../data/levels"
Blocks = require "../data/blocks"
Player = require "../class/player"
EventEmitter = require("events").EventEmitter

util = require "util"

module.exports = class extends EventEmitter
  constructor: (@io, @server) ->
    @players = []
    @playerId = 0
    @colors = ['green', 'orange', 'pink', 'blue']
    @tmpColors = []
    @ended = false

    @levels = new Levels()
    @blocks = new Blocks()

    @id = +new Date()
    @tmpColors = @colors.slice(0)

    @level = @levels.getRandomLevel()
    @board = {}

    # create empty board
    for i in [0...13]
      for j in [0...15]
        unless @board.hasOwnProperty i
          @board[i] = {}

        @board[i][j] = -1

    # put level into board
    for i in [0...5]
      for j in [0...5]
        @board[4+i][5+j] = @level.data[i][j]

  addPlayer: (player) ->
    @playerId++
    player.id = @playerId

    player.color = @tmpColors[0]
    player.blockId = @level.blocks[0]
    player.block = @blocks.blocks[player.blockId]

    switch @colors.indexOf(player.color)
      when 0
        player.position = { x: 1, y: 1 }
      when 1
        player.position = { x: Object.keys(@board[0]).length - player.block[0].length - 1, y: 1 }
      when 2
        player.position = { x: Object.keys(@board[0]).length - player.block[0].length - 1, y: Object.keys(@board).length - player.block.length - 1 }
      when 3
        player.position = { x: 1, y: Object.keys(@board).length - player.block.length - 1 }

    @tmpColors.shift()
    @level.blocks.shift()

    @players.push(player)
    player.socket.join("game-#{@id}")

    players = {}
    for player in @players
      players[player.id] = player.safeObj()

    player.socket.emit "gamedata",
      board: @board
      players: players

    @broadcastPlayerJoin(player)

    player.socket.on "move", (direction) => @onPlayerMove player, direction
    player.socket.on "rotation", (direction) => @onPlayerRotation player, direction
    player.socket.on "flip", => @onPlayerFlip player
    player.socket.on "disconnect", => @onPlayerDisconnect player

  startGame: ->
    @broadcastInitialData()


  checkBounds: (player, direction) =>
    switch direction
      when 0 # right
        player.position.x + player.block[0].length < Object.keys(@board[0]).length
      when 1 # down
        player.position.y + player.block.length < Object.keys(@board).length
      when 2 # left
        player.position.x > 0
      when 3 # up
        player.position.y > 0

  checkSolved: =>
    matchedTiles = 0
    fittingTiles = 0
    boardCopy = []

    for key, val of @board
      boardCopy[key] ?= []
      for k, v of val
        boardCopy[key].push v
        if v is 1
          fittingTiles++

    if global.debug
      console.log "Fitting tiles: #{fittingTiles}"

    for player in @players
      console.log player.position
      for i in [0...player.block.length]
        for j in [0...player.block[i].length]
          y = player.position.y + i
          x = player.position.x + j
          if boardCopy[y][x] is 1 and player.block[i][j] is 1
            boardCopy[y][x] = 2
            matchedTiles++

    if global.debug
      util.print "|-"
      for i in [0...boardCopy[0].length]
        util.print "--"
      util.print "-|\n"

      for i in [0...boardCopy.length]
        util.print "| "
        for j in [0...boardCopy[i].length]
          tile = boardCopy[i][j]
          switch tile
            when -1
              util.print "  "
            when 1
              util.print "- "
            when 2
              util.print "# "
        util.print " |\n"

      util.print "|-"
      for i in [0...boardCopy[0].length]
        util.print "--"
      util.print "-|\n"

      console.log "MatchedTiles: #{matchedTiles}"

    if matchedTiles is fittingTiles
      @ended = true

      @emit "game_ended"

      usersToKick = @players.slice(0)
      for player in usersToKick
        player.socket.emit "winning"
        player.socket.disconnect()

  fixPlayerPosition: (player) =>
    if parseInt(player.position.x) + parseInt(player.block[0].length) >= Object.keys(@board[0]).length
      player.position.x = Object.keys(@board[0]).length - player.block[0].length

    if parseInt(player.position.y) + parseInt(player.block.length) >= Object.keys(@board).length
      player.position.y = Object.keys(@board).length - player.block.length

  onPlayerMove: (player, direction) =>
    if @checkBounds(player, direction)
      switch direction
        when 0
          player.position.x += 1
        when 1
          player.position.y += 1
        when 2
          player.position.x -= 1
        when 3
          player.position.y -= 1

      @broadcastMove player
      @checkSolved()

  onPlayerRotation: (player, direction) =>
    player.rotateBlock()
    @fixPlayerPosition player
    @broadcastMove player
    @checkSolved()

  onPlayerFlip: (player) =>
    player.flipBlock()
    @broadcastMove player
    @checkSolved()

  onPlayerDisconnect: (player) =>
    if not @ended and not player.willDisconnect
      console.log "onPlayerDisconnect"
      for p in @players when p isnt player
        console.log "setting #{p.name} to willDisconnect"
        p.willDisconnect = true

      @emit "game_ended", "`#{player.name}` left the game"

  broadcastInitialData: ->
    players = {}
    for player in @players
      players[player.id] = player.safeObj()

    @io.sockets.in("game-#{@id}").emit "gamedata",
      board: @board
      players: players    

  broadcastMove: (movingPlayer) ->
    for player in @players
      player.socket.emit "move", movingPlayer.safeObj()

  broadcastPlayerJoin: (newPlayer) ->
    for player in @players
      unless player is newPlayer
        player.socket.emit "player_join", newPlayer.safeObj()    

  broadcastPlayerLeave: (leftPlayer) ->
    for player in @players
      player.socket.emit "player_leave", leftPlayer.safeObj()    
