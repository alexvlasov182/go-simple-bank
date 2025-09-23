package main

import (
	"backend/go-simple-bank/api"
	db "backend/go-simple-bank/db/sqlc"
	"backend/go-simple-bank/util"
	"database/sql"
	"log"

	_ "github.com/lib/pq"
)

func main() {
	// config
	config, err := util.LoadConfig(".")
	if err != nil {
		log.Fatal("cannot load config:", err)
	}

	// connect to database
	conn, err := sql.Open(config.DBDriver, config.DBSource)
	if err != nil {
		log.Fatal("cannot connect to db:", err)
	}

	// create store and
	store := db.NewStore(conn)
	server, err := api.NewServer(config, store)
	if err != nil {
		log.Fatal("cannot create server:", err)
	}

	// run server
	err = server.Start(config.ServerAddress)
	if err != nil {
		log.Fatal("cannot start server:", err)
	}
}
