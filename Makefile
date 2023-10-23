NAME = flz

SRCF = ./src/
SRC_NAME = main.c \
	utils.c \
	window_positions.c \
	overlay.c

OBJF = ./obj/
OBJS = $(addprefix $(OBJF), $(SRC_NAME:.c=.o))

CC = gcc
CFLAGS = -I./include
LDFLAGS = -lX11 -lXfixes -lXi

all : $(NAME)

$(NAME) : $(OBJS)
	$(CC) -o $(NAME) $(OBJS) $(LDFLAGS)

$(OBJF)%.o : $(SRCF)%.c
	@mkdir -p $(@D)
	$(CC) -o $@ $(CFLAGS) -c $(addprefix $(SRCF), $*.c)

clean :
	rm -rf $(OBJS)

fclean : clean
	rm -rf $(NAME)

re : fclean all