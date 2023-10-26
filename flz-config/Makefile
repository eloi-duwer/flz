NAME = flz-config

BIN = ../bin/$(NAME)

SRCF = ./src/
SRC_NAME = main.c

OBJF = ./obj/
OBJS = $(addprefix $(OBJF), $(SRC_NAME:.c=.o))

CC = gcc
CFLAGS = -I./include
LDFLAGS = -lX11 -lXfixes -lXi

all : $(NAME)

$(NAME) : $(OBJS)
	$(CC) -o $(BIN) $(OBJS) $(LDFLAGS)

$(OBJF)%.o : $(SRCF)%.c
	@mkdir -p $(@D)
	$(CC) -o $@ $(CFLAGS) -c $(addprefix $(SRCF), $*.c)

clean :
	rm -rf $(OBJS)

fclean : clean
	rm -rf $(BIN)

re : fclean all