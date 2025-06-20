test:
    nvim --headless \
        --noplugin \
        -u NONE \
        -c "set rtp+=." \
        -c "runtime plugin/plenary.vim" \
        -c "PlenaryBustedDirectory tests/"
