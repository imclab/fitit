Player = require "./class/player"
Game   = require "./class/game"

module.exports = class
  queue: []
  games: []
  constructor: (@io) ->
    @io.on "connection", @onConnection

  onConnection: (socket) =>
    socket.on "name", (name) =>
      socket.playerName = name

      incompleteGame = null
      for game in @games when game.players.length < 4
        incompleteGame = game
        break

      if incompleteGame
        player = new Player(socket)
        incompleteGame.addPlayer(player)
      else
        @queue.push socket

        for waitingSocket in @queue
          waitingSocket.emit "queue_length", @queue.length

        socket.inQueue = true
        socket.on "disconnect", =>
          if socket.inQueue
            if ~@queue.indexOf(socket)
              @queue.splice @queue.indexOf(socket), 1

            for waitingSocket in @queue
              waitingSocket.emit "queue_length", @queue.length

        @checkQueue()

  checkQueue: ->
    if @queue.length is 4
      game = new Game(@io, this)
      for socket in @queue
        socket.inQueue = false
        player = new Player(socket)
        game.addPlayer(player)

      game.on "game_ended", (err) =>
        if ~@games.indexOf(game)
          @games.splice(@games.indexOf(game), 1)

        if err?
          for p in game.players
            unless game.ended
              p.socket.emit "game_ended", err

      @queue = []

      game.startGame()

      @games.push game

  getLongestWaitingSocket: ->
    if @queue.length > 0
      socket = @queue[0]

      # remove socket from queue
      @queue.splice(@queue.indexOf(socket), 1)

      return socket
    else
      return false

