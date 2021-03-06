//
//  SQLiteViewer.swift
//  SQLite.viewer
//
//  Created by Orkhan Alikhanov on 7/2/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import HttpSwift
import SQLite

open class SQLiteViewer {
    open static var shared = SQLiteViewer()
    
    public var assetDir: String = ""
    public var dbDir: String = "" {
        didSet {
            db = DatabaseController(path: dbDir)
        }
    }
    
    lazy var server: Server = {
        let server = Server()
        self.prepareServer(server)
        return server
    }()
    
    open var db: DatabaseController!
    
    func prepareServer(_ server: Server) {
        server.errorHandler = SQLiteErrorHanler.self
        
        let assetDir = self.assetDir
        let db = self.db!
        server.get("/") { _ in
            return try StaticServer.serveFile(in: assetDir, path: "index.html")
        }
        
        server.group("api") {
            server.group("databases") {
                server.get("/") { _ in
                    return .success(try db.getList())
                }
                
                server.group("/{name}") {
                    server.get("/tables/{table-name}") { r in
                        let dbName = r.routeParams["name"]!
                        let table = r.routeParams["table-name"]!
                        
                        return .success(try db.getTableData(db: dbName, table: table))
                    }
                    
                    server.get("/tables") { r in
                        let dbName = r.routeParams["name"]!
                        return .success(try db.getTableList(db: dbName))
                    }
                    
                    server.get("/download") { r in
                        let dbName = r.routeParams["name"]!
                        let path = "\(self.dbDir)/\(dbName)"
                        if !File(path: path).exists {
                            throw SQLite.Result.error(message: "no such database: \(dbName)", code: 1, statement: nil)
                        }
                        
                        return try StaticServer.serveFile(at: "\(self.dbDir)/\(dbName)")
                        }.middleware { request, closure in
                            let response = try closure(request)
                            let dbName = request.routeParams["name"]!
                            response.headers["Content-Type"] = "application/octet-stream"
                            response.headers["Content-Disposition"] = "attachment; filename=\"\(dbName)\""
                            return response
                       }
                    
                    server.get("/execute") { r in
                        if let query = r.queryParams["query"] {
                            let dbName = r.routeParams["name"]!
                            return .success(try db.executeRawQuery(db: dbName, query: query))
                        }
                        
                        return .error("Query is missing. use `/execute?query=insert...`")
                    }
                }
            }
        }
        
        
        server.files(in: assetDir)
    }
    
    open func start(port: UInt16 = 8081, dbDir: String? = nil, assetDir: String? = nil) {
        self.dbDir = dbDir ?? NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        self.assetDir = assetDir ?? Bundle(for: SQLiteViewer.self).resourceURL!.appendingPathComponent("com.biatoms.sqlite-viewer.assets.bundle").path
        server.run(port: port)
    }
    
    open func stop() {
        server.stop()
    }
}
