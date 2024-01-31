format ELF executable 3
entry start

segment readable executable

    start:

        call random_seed_now
        call generate_maze

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
                mov cx,  [ren_i] ; c = ren_i
                add ecx, map     ; c = map+ren_i
                xor eax, eax     ; a = 0
                mov al,  [ecx]   ; a = map[ren_i]
                mov ebx, 3
                mul ebx
                mov ecx, eax     ; c = map[ren_i]
                add ecx, ren     ; c = ren+map[ren_i] (a pointer to the character to be displayed from the render sheet)

            ren_post:

            mov eax, 4 ; WRITE
            mov ebx, 1 ; STDOUT
            mov edx, 3 ; 
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

    random:

        mov eax, [rng_s]
        mov ebx, rng_a
        mul ebx
        add eax, rng_c

        mov [rng_s], eax
        
        shr eax, 10
        and eax, 15

        mov [rng_v], eax

    ret

    random_seed_now:

        mov eax, 43
        mov ebx, 0
        int 80h

        add [rng_s], eax

    ret

    generate_maze:

        mov [mzi], width + 1 ; Starts generating the maze at 1,1
        mov [mzn], 0         ; Initializes the iteration count to 0, used later for backtracking

        mov eax, 0
        maze_fill: ; Fills the entire maze with walls

            mov [eax + map], 1

            add eax, 1
            cmp eax, width * height
            jne maze_fill

        mov eax,       [mzi]
        mov [eax+map], 0     ; Sets the starting cell to empty

        ; Sets the bottom-most value of the stack to the starting position
        mov eax,  [mzs]
        mov ebx,  [mzi]
        mov [eax], ebx

        generate_maze_loop:

            add [mzn], 1

            ; Computes the x and y coordinates corresponding to the current index
            mov eax, [mzi]
            xor edx, edx
            mov ecx, width
            div ecx
            mov [mzx], edx
            mov [mzy], eax

            ; First, checks whether it is the first iteration
            ; if not, it then checks if the top-most value on the stack is the starting position,
            ; in which case it returns from the routine
            cmp [mzn], 1
            je  generate_maze_flags
            mov eax, [mzi]
            cmp eax, width + 1
            jne generate_maze_flags
            mov [map+width*height-width-2], 2
            ret

            generate_maze_flags:
                mov eax, 15

                ; Checks if the generator is at the top / left / bottom / right edge,
                ; in which case it removes it from the available moves
            
                cmp [mzx], 1
                jne no_left
                and eax, C_L
                no_left: 
                
                cmp [mzx], width-2
                jne no_right
                and eax, C_R
                no_right: 
                
                cmp [mzy], 1
                jne no_up
                and eax, C_U
                no_up:

                cmp [mzy], height-2
                jne no_down
                and eax, C_D
                no_down:

                ; Move back if no valid option is available
                cmp eax, 0
                je go_back

                ; Checks for each direction, if the generator can move towards it, it checks
                ; if the cell at that position is already explored, in which case it removes
                ; it from the available moves

                mov ebx, eax            ; b = flags
                and ebx, D_L            ; b = flags & D_L
                cmp ebx, 0              ; if (flags & D_L == 0)
                je  no_chk_left         ;   goto no_chk_left
                mov ebx, [mzi]          ; b = i
                cmp [ebx+map-2], byte 0 ; if (map[i-2] != 0)
                jne no_chk_left         ;   goto no_chk_left
                and eax, C_L            ; flags &= C_L
                no_chk_left:            ; 

                mov ebx, eax            ; b = flags
                and ebx, D_R            ; b = flags & D_R
                cmp ebx, 0              ; if (flags & D_R == 0)
                je  no_chk_right        ;   goto no_chk_right
                mov ebx, [mzi]          ; b = i
                cmp [ebx+map+2], byte 0 ; if (map[i+2] != 0)
                jne no_chk_right        ;   goto no_chk_right
                and eax, C_R            ; flags &= C_R
                no_chk_right:           ; 

                mov ebx, eax                  ; b = flags
                and ebx, D_U                  ; b = flags & D_U
                cmp ebx, 0                    ; if (flags & D_U == 0)
                je  no_chk_up                 ;   goto no_chk_up
                mov ebx, [mzi]                ; b = i
                cmp [ebx+map-width*2], byte 0 ; if (map[i-2*width] != 0)
                jne no_chk_up                 ;   goto no_chk_up
                and eax, C_U                  ; flags &= C_U
                no_chk_up:                    ; 

                mov ebx, eax                  ; b = flags
                and ebx, D_D                  ; b = flags & D_D
                cmp ebx, 0                    ; if (flags & D_D == 0)
                je  no_chk_down               ;   goto no_chk_down
                mov ebx, [mzi]                ; b = i
                cmp [ebx+map+width*2], byte 0 ; if (map[i+2*width] != 0)
                jne no_chk_down               ;   goto no_chk_down
                and eax, C_D                  ; flags &= C_D
                no_chk_down:                  ; 

                ; Move back if no valid option is available
                cmp eax, 0
                je go_back

                mov [tmp], eax ; Saves the move flags into tmp

                generate_maze_rng: ; Generates a new random number that will allow one move or more

                    call random

                    ; Ands the generated number with the move flags
                    mov ebx, [tmp]
                    and ebx, [rng_v]

                    ; Tries to generate another one if no bit is left set in the move flags
                    cmp ebx, 0
                    je  generate_maze_rng

                mov eax, ebx

                ; Moves the generator according to the first bit set in the move flags

                mov ebx,       eax    ; b = flags
                and ebx,       D_L    ; b = flags & D_L
                cmp ebx,       0      ; if (flags & D_L == 0)
                je  maze_left         ;   goto maze_left
                mov ebx,       [mzi]  ; b = mzi
                sub ebx,       1      ; b = mzi - 1
                mov [ebx+map], byte 0 ; map[mzi - 1] = 0
                sub ebx,       1      ; b = mzi - 2
                mov [mzi],     ebx    ; mzi = mzi - 2
                mov [ebx+map], byte 0 ; map[mzi] = 0
                jmp maze_down
                maze_left:

                mov ebx,       eax    ; b = flags
                and ebx,       D_R    ; b = flags & D_R
                cmp ebx,       0      ; if (flags & D_R == 0)
                je  maze_right        ;   goto maze_right
                mov ebx,       [mzi]  ; b = mzi
                add ebx,       1      ; b = mzi + 1
                mov [ebx+map], byte 0 ; map[mzi + 1] = 0
                add ebx,       1      ; b = mzi + 2
                mov [mzi],     ebx    ; mzi = mzi + 2
                mov [ebx+map], byte 0 ; map[mzi] = 0
                jmp maze_down
                maze_right:

                mov ebx,       eax    ; b = flags
                and ebx,       D_U    ; b = flags & D_U
                cmp ebx,       0      ; if (flags & D_U == 0)
                je  maze_up           ;   goto maze_up
                mov ebx,       [mzi]  ; b = mzi
                sub ebx,       width  ; b = mzi - width
                mov [ebx+map], byte 0 ; map[mzi - width] = 0
                sub ebx,       width  ; b = mzi - 2*width
                mov [mzi],     ebx    ; mzi = mzi - 2*width
                mov [ebx+map], byte 0 ; map[mzi] = 0
                jmp maze_down
                maze_up:

                mov ebx,       eax    ; b = flags
                and ebx,       D_D    ; b = flags & D_D
                cmp ebx,       0      ; if (flags & D_D == 0)
                je  maze_down         ;   goto maze_down
                mov ebx,       [mzi]  ; b = mzi
                add ebx,       width  ; b = mzi + width
                mov [ebx+map], byte 0 ; map[mzi + width] = 0
                add ebx,       width  ; b = mzi + 2*width
                mov [mzi],     ebx    ; mzi = mzi + 2*width
                mov [ebx+map], byte 0 ; map[mzi] = 0
                jmp maze_down
                maze_down:

                ; mzs.push(mzi)
                mov eax,   [mzs]
                add eax,   4
                mov ebx,   [mzi]
                mov [eax], ebx
                mov [mzs], eax 

                jmp generate_maze_loop

            go_back:

                ; mzi = mzs.pop()
                mov eax,   [mzs]
                mov ebx,   [eax]
                mov [mzi], ebx
                sub eax,   4
                mov [mzs], eax

                jmp generate_maze_loop

    ret

    quit: ; Exists the program

        mov eax, 1
        xor ebx, ebx
        int 80h

segment readable writeable

    tmp dd ?

    D_L = 2
    D_R = 1
    D_D = 4
    D_U = 8

    C_L = 13
    C_R = 14
    C_D = 11
    C_U = 7

    rng_v dd ?
    rng_s dd 1245
    rng_a =  1103515245
    rng_c =  12345

    ; Whether the next frame should be displayed
    ; (disabled whenever the newline character is processed)
    ren_do db 1

    ; The winning message
    won_msg db "Congrats ! You won !", 10
    won_len =  $ - won_msg

    ren_i dw ? ; Current index in the rendering loop
    ren_c dw ? ; Current column in the rendering loo
    ren_l dw ? ; Current line in the rendering loop

    inp_v dw ? ; Current input character

    ren db 0,0," █",0,0,"+" ; The characters used for rendering the board cells
    nwl db 10    ; Newline character
    plr db 0,0,"@"   ; The character used to render the player

    ; Player position before it moves
    qx dw ?
    qy dw ?

    ; Current player position
    px dw 1
    py dw 1

    ; Map size and data
    width  = 51
    height = 31
    map    rb width * height

    mzx dd ?
    mzy dd ?
    mzi dd ?
    mzn dd ?

    mzs      dd mzs_base
    mzs_base rd width * height
