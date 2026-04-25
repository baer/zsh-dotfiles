cask_args appdir: '/Applications'

# Load cask skip list from ~/.localrc if not already in environment
if ENV['HOMEBREW_BUNDLE_CASK_SKIP'].nil? || ENV['HOMEBREW_BUNDLE_CASK_SKIP'].empty?
  localrc = File.expand_path('~/.localrc')
  if File.exist?(localrc)
    File.read(localrc).match(/^export HOMEBREW_BUNDLE_CASK_SKIP="([^"]*)"/) do |m|
      ENV['HOMEBREW_BUNDLE_CASK_SKIP'] = m[1]
    end
  end
end

# Load mas skip list from ~/.localrc if not already in environment
if ENV['HOMEBREW_BUNDLE_MAS_SKIP'].nil? || ENV['HOMEBREW_BUNDLE_MAS_SKIP'].empty?
  localrc = File.expand_path('~/.localrc')
  if File.exist?(localrc)
    File.read(localrc).match(/^export HOMEBREW_BUNDLE_MAS_SKIP="([^"]*)"/) do |m|
      ENV['HOMEBREW_BUNDLE_MAS_SKIP'] = m[1]
    end
  end
end

tap 'homebrew/brew-vulns'
tap 'stripe/stripe-cli'

# Dotfiles-managed CLI dependencies. Keep user-installed extras out of this
# list unless they are required by the shell, scripts, or checked-in config.
brew 'atuin'
brew 'awscli'
brew 'bash'
brew 'bat'
brew 'bats-core'
brew 'btop'
brew 'cloudflared'
brew 'coreutils'
brew 'eza'
brew 'fd'
brew 'fzf'
brew 'gh'
brew 'git'
brew 'git-delta'
brew 'grc'
brew 'homebrew/brew-vulns/brew-vulns'
brew 'hyperfine'
brew 'imagemagick'
brew 'jq'
brew 'lazygit'
brew 'mas'
brew 'mise'
brew 'openssl'
brew 'postgresql@18'
brew 'ripgrep'
brew 'sqlite'
brew 'starship'
brew 'tldr'
brew 'wget'
brew 'zoxide'
brew 'zsh'
brew 'zsh-autosuggestions'
brew 'zsh-completions'
brew 'zsh-fast-syntax-highlighting'

# Managed applications and fonts.
cask '1password'
cask 'audacity'
cask 'claude'
cask 'cloudflare-warp'
cask 'claude-code'
cask 'codex'
cask 'font-fira-code'
cask 'font-hack-nerd-font'
cask 'font-victor-mono'
cask 'garmin-express'
cask 'ghostty'
cask 'google-chrome'
cask 'google-drive'
cask 'grammarly-desktop'
cask 'keepingyouawake'
cask 'ngrok'
cask 'obsidian'
cask 'rectangle'
cask 'signal'
cask 'slack'
cask 'spotify'
cask 'visual-studio-code'
cask 'whatsapp'
cask 'zoom'
