class SiteController < ApplicationController
  before_filter :authenticate_user, except: [:index]
  before_filter :find_game,         except: [:index]
  before_filter :ensure_game,       only:   [:guess, :eliminate, :won]
  before_filter :find_guess,        only:   [:guess, :eliminate]

  rescue_from Koala::Facebook::APIError, OAuth2::Error,
    OmniAuth::Strategies::OAuth2::CallbackError do |exception|
    notify_exception exception

    if exception.kind_of?(OAuth2::Error) ||
       exception.kind_of?(OmniAuth::Strategies::OAuth2::CallbackError) ||
      (exception.respond_to?(:fb_error_code) && exception.fb_error_code.to_i == 190)

      new_game!
      self.current_user = nil
    end

    if request.xhr?
      head 500
    elsif request.path != root_path
      redirect_to root_path
    else
      render 'public/500.html'
    end
  end

  # Displays the home page.
  #
  def index
    @players = Game.leaderboard.limit(10)
  end

  # Starts a new game if no current game is in progress, or
  # resumes the last played game. But - if the current game
  # is empty, remove it and start a new one.
  #
  def play
    if @game
      if @game.guesses.present?
        @friends = gather_friends_from(@game)
      else
        new_game!
        @game = nil
      end
    end
  end

  # AJAX Call
  def stalk
    @game    = Game.make(current_user, current_game)
    @friends = gather_friends_from(@game)

    render :partial => 'board'
  end

  # Returns the next hint for the current game as a JSON string.
  #
  def hint
    render :json => @game.next_hint
  end

  # Abandons the current game and starts a new one.
  #
  def restart
    new_game!
    redirect_to play_path
  end

  # Abandons the current game and redirects to the home page.
  #
  def abandon
    new_game!
    redirect_to root_path
  end

  # Called when an user eliminates a guess. If it is right, then
  # 200 is returned, else 418 - I'm a Teapot ;-).
  #
  # Renders the current game score as text.
  #
  # Params:
  #
  #  * id: Facebook User ID of the guess to be eliminated.
  #
  def eliminate
    status = @game.eliminate!(@guess) ? :ok : 418
    render :text => @game.score, :status => status
  end

  # Guesses the mysterious friend.
  def guess
    status = @game.guess!(@guess) ? :ok : 418
    render :text => @game.score, :status => status
  end

  # Reveals who is the mysterious friend to guess. This sucks, as
  # is the only endpoint you can use to hack the app, but it is needed
  # to make the "I Got It" mode display who was the mysterious friend
  # after you chose the wrong one. Gotcha!
  def reveal
    render :json => @game.target_id
  end

  # Nothing for now - this used to spam friends' walls.
  # See the git log for the code...
  def won
    head(:no_content)
  end

  private
  def find_game
    @game = Game.by_token(current_game)
  end

  def ensure_game
    head :bad_request unless @game
  end

  def find_guess
    @guess = params[:id]

    if @guess.blank? || !@game.valid_guess?(@guess)
      head :bad_request
    end
  end

  def gather_friends_from(game)
    friends = game.people

    if friends.size < Game.cards
      friends.concat Array.new(Game.cards - friends.size)
      friends.shuffle!
    end

    return friends
  end

end
