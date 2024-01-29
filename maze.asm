format ELF executable 3
entry start

segment readable executable

    start:

        ; Updates the 'old' player position to the current one
        call move_end

        game_loop:

            call render
            call input

        jmp game_loop

    render:

        ; Skips rendering the current frame if it should not
        cmp [ren_do], 1
        je  no_skip

            mov [ren_do], 1
            ret
        
        no_skip:

        ; Set up the rendering status
        mov [ren_i], 0
        mov [ren_c], 0
        mov [ren_l], 0

        render_loop:
            ; ( ecx is the address of the character to be displayed )

            xor ecx, ecx

            ; Compares the current position against the player's to render either one
            mov ax,   [ren_c]
            cmp [px], ax
            jne ren_map
            
            mov ax,   [ren_l]
            cmp [py], ax
            jne ren_map

            ; Sets the character to be displayed to be the player's
            mov ecx, plr

            jmp ren_post

            ren_map:

                ; ecx := ren[map[ren_i]]
                mov cl,  byte[ren_i] ; c = ren_i
                add ecx, map         ; c = map+ren_i
                xor eax, eax         ; a = 0
                mov al,  [ecx]       ; a = map[ren_i]
                mov ecx, eax         ; c = map[ren_i]
                add ecx, ren         ; c = ren+map[ren_i] (a pointer to the character to be displayed from the render sheet)

            ren_post:

            mov eax, 4 ; WRITE
            mov ebx, 1 ; STDOUT
            mov edx, 1 ; 1 character
            int 80h    ; syscall

            ; Increases the column by 1
            ; then checks whether it is equal to the width of the map,
            ; in which case it resets it, increases the current line, and displays a newline
            add [ren_c], 1
            cmp [ren_c], width
            jne no_newline

                mov [ren_c], 0
                add [ren_l], 1

                mov eax, 4   ; WRITE
                mov ebx, 1   ; STDOUT
                mov ecx, nwl ; newline
                mov edx, 1   ; 1 character
                int 80h      ; syscall

            no_newline:

            ; Increases the current cell index,
            ; then checks whether it is equal to the board size,
            ; in which case it jumps back to the top of the loop
            ; otherwise, it just falls through and returns
            add [ren_i], 1
            cmp [ren_i], width * height
            jl  render_loop

    ret

    input:

        mov eax, 3     ; READ
        mov ebx, 0     ; STDIN
        mov ecx, inp_v ; data
        mov edx, 1     ; 1 character
        int 80h        ; syscall

        cmp [inp_v], 'i'
        je  move_up

        cmp [inp_v], 'j'
        je  move_left

        cmp [inp_v], 'k'
        je  move_down

        cmp [inp_v], 'l'
        je  move_right

        cmp [inp_v], 'q'
        je  quit

        ; Ignores the trailing newline character
        cmp [inp_v], 10
        je  ignore

        ret

        move_up:
            sub [py], 1
        jmp move_check
        
        move_down:
            add [py], 1
        jmp move_check
        
        move_left:
            sub [px], 1
        jmp move_check
        
        move_right:
            add [px], 1
        
        move_check: ; Checks the cell on which the player is to determine what to do

            ; Retreives the cell of the player into eax
            xor eax, eax   ; a = 0
            mov ax,  [py]  ; a = py
            mov ebx, width ; b = width
            mul ebx        ; a = py * b = py * width
            add ax,  [px]  ; a = py * width + px ( the index of the cell of the player )
            add eax, map   ; a = map + py * width + px ( the address of the cell of the player )

            ; Jumps to win if the player has reached the end
            cmp [eax], byte 2
            je  move_win

            ; Jumps to fail if the player is inside a wall
            cmp [eax], byte 0
            jne move_fail

            jmp move_end

        move_win: ; Prints the win message and ends the game

            call render

            mov eax, 4
            mov ebx, 1
            mov ecx, won_msg
            mov edx, won_len
            int 80h

            jmp quit

        move_fail: ; Moves the player to its old position

            mov ax,  [qx]
            mov [px], ax

            mov ax,  [qy]
            mov [py], ax

        ret

        move_end: ; Sets the old player position to the current one

            mov ax,  [px]
            mov [qx], ax

            mov ax,  [py]
            mov [qy], ax

        ret

        ignore: ; Prevents the next frame to be rendered in case of the trailing newline

            mov [ren_do], 0

        ret

    quit: ; Exists the program

        mov eax, 1
        xor ebx, ebx
        int 80h

segment readable writeable

    ; Whether the next frame should be displayed
    ; (disabled whenever the newline character is processed)
    ren_do db 1

    ; The winning message
    won_msg db "Congrats ! You won !", 10
    won_len =  $ - won_msg

    ren_i dw ? ; Holds the current index in the rendering loop
    ren_c dw ? ; Holds the current column in the rendering loo
    ren_l dw ? ; Holds the current line in the rendering loop

    inp_v dw ? ; Holds the current input characte

    ren db " #." ; The characters used for rendering the board cells
    nwl db 10    ; Newline character
    plr db "@"   ; The character used to render the player

    ; Player position before it moves
    qx dw ?
    qy dw ?

    ; Current player position
    px dw 3
    py dw 3

    ; Map size and data
    width  = 5
    height = 5
    map    db 1, 1, 1, 1, 1, \
              1, 2, 0, 0, 1, \
              1, 0, 1, 0, 1, \
              1, 0, 0, 0, 1, \
              1, 1, 1, 1, 1