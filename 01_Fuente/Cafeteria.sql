USE master;
GO
SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;
IF @@TRANCOUNT <> 0
    THROW 51000, 'Ejecute desde una conexion sin transacciones pendientes.', 1;
DROP TABLE IF EXISTS #Cafeteria_Instalacion;
IF DB_ID(N'Cafeteria') IS NOT NULL
    THROW 51001, 'Cafeteria ya existe. No se modifico. Use otra base para reinstalar.', 1;
EXEC(N'CREATE DATABASE [Cafeteria];');
EXEC(N'ALTER DATABASE [Cafeteria] SET COMPATIBILITY_LEVEL = 160;');
CREATE TABLE #Cafeteria_Instalacion (DatabaseID int NOT NULL);
INSERT #Cafeteria_Instalacion VALUES (DB_ID(N'Cafeteria'));
GO
USE Cafeteria;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
IF DB_NAME() <> N'Cafeteria' OR OBJECT_ID('tempdb..#Cafeteria_Instalacion') IS NULL
    THROW 51002, 'Instalacion no autorizada por el primer lote. Ejecute el archivo completo.', 1;
IF NOT EXISTS (SELECT 1 FROM #Cafeteria_Instalacion WHERE DatabaseID = DB_ID())
    THROW 51003, 'La base actual no coincide con la base creada.', 1;
BEGIN TRY
BEGIN TRANSACTION;

-- 1. Catalogos: nombres descriptivos dependen exclusivamente de su clave.
CREATE TABLE dbo.Categoria (
    CategoriaID int NOT NULL CONSTRAINT PK_Categoria PRIMARY KEY,
    Nombre nvarchar(80) NOT NULL CONSTRAINT UQ_Categoria_Nombre UNIQUE
);
CREATE TABLE dbo.Marca (
    MarcaID int NOT NULL CONSTRAINT PK_Marca PRIMARY KEY,
    Nombre nvarchar(80) NOT NULL CONSTRAINT UQ_Marca_Nombre UNIQUE
);
CREATE TABLE dbo.TipoPlato (
    TipoPlatoID int NOT NULL CONSTRAINT PK_TipoPlato PRIMARY KEY,
    Nombre nvarchar(50) NOT NULL CONSTRAINT UQ_TipoPlato_Nombre UNIQUE
);
CREATE TABLE dbo.TemperaturaServicio (
    TemperaturaID int NOT NULL CONSTRAINT PK_Temperatura PRIMARY KEY,
    Nombre nvarchar(30) NOT NULL CONSTRAINT UQ_Temperatura_Nombre UNIQUE
);
CREATE TABLE dbo.MetodoPago (
    MetodoPagoID int NOT NULL CONSTRAINT PK_MetodoPago PRIMARY KEY,
    Nombre nvarchar(40) NOT NULL CONSTRAINT UQ_MetodoPago_Nombre UNIQUE
);
CREATE TABLE dbo.TipoPedido (
    TipoPedidoID int NOT NULL CONSTRAINT PK_TipoPedido PRIMARY KEY,
    Nombre nvarchar(40) NOT NULL CONSTRAINT UQ_TipoPedido_Nombre UNIQUE
);
CREATE TABLE dbo.EstadoPedido (
    EstadoPedidoID int NOT NULL CONSTRAINT PK_EstadoPedido PRIMARY KEY,
    Nombre nvarchar(30) NOT NULL CONSTRAINT UQ_EstadoPedido_Nombre UNIQUE
);
CREATE TABLE dbo.Rol (
    RolID int NOT NULL CONSTRAINT PK_Rol PRIMARY KEY,
    Nombre nvarchar(40) NOT NULL CONSTRAINT UQ_Rol_Nombre UNIQUE
);
CREATE TABLE dbo.Sucursal (
    SucursalID int NOT NULL CONSTRAINT PK_Sucursal PRIMARY KEY,
    Nombre nvarchar(80) NOT NULL CONSTRAINT UQ_Sucursal_Nombre UNIQUE,
    Direccion nvarchar(200) NOT NULL,
    FechaApertura date NOT NULL
);
CREATE TABLE dbo.Mesa (
    MesaID int NOT NULL CONSTRAINT PK_Mesa PRIMARY KEY,
    SucursalID int NOT NULL CONSTRAINT FK_Mesa_Sucursal REFERENCES dbo.Sucursal,
    Numero smallint NOT NULL,
    Capacidad tinyint NOT NULL CONSTRAINT CK_Mesa_Capacidad CHECK(Capacidad BETWEEN 1 AND 20),
    CONSTRAINT UQ_Mesa_Numero UNIQUE(SucursalID, Numero),
    CONSTRAINT CK_Mesa_Numero CHECK(Numero > 0)
);
CREATE TABLE dbo.Empleado (
    EmpleadoID int NOT NULL CONSTRAINT PK_Empleado PRIMARY KEY,
    Nombre nvarchar(80) NOT NULL,
    Apellido nvarchar(100) NOT NULL,
    RolID int NOT NULL CONSTRAINT FK_Empleado_Rol REFERENCES dbo.Rol,
    FechaIngreso date NOT NULL,
    Activo bit NOT NULL CONSTRAINT DF_Empleado_Activo DEFAULT 1
);
CREATE TABLE dbo.Vehiculo (
    VehiculoID int NOT NULL CONSTRAINT PK_Vehiculo PRIMARY KEY,
    Placa varchar(10) NOT NULL CONSTRAINT UQ_Vehiculo_Placa UNIQUE,
    Descripcion nvarchar(80) NOT NULL
);
CREATE TABLE dbo.Turno (
    TurnoID int NOT NULL CONSTRAINT PK_Turno PRIMARY KEY,
    Nombre nvarchar(30) NOT NULL CONSTRAINT UQ_Turno_Nombre UNIQUE
);
CREATE TABLE dbo.EmpleadoTurno (
    EmpleadoID int NOT NULL CONSTRAINT PK_EmpleadoTurno PRIMARY KEY CONSTRAINT FK_EmpleadoTurno_Empleado REFERENCES dbo.Empleado,
    TurnoID int NOT NULL CONSTRAINT FK_EmpleadoTurno_Turno REFERENCES dbo.Turno
);
CREATE TABLE dbo.Caja (
    CajaID int NOT NULL CONSTRAINT PK_Caja PRIMARY KEY,
    SucursalID int NOT NULL CONSTRAINT FK_Caja_Sucursal REFERENCES dbo.Sucursal,
    Nombre nvarchar(30) NOT NULL,
    CONSTRAINT UQ_Caja_Nombre UNIQUE(SucursalID,Nombre)
);
CREATE TABLE dbo.CajeroCaja (
    EmpleadoID int NOT NULL CONSTRAINT FK_CajeroCaja_Empleado REFERENCES dbo.Empleado,
    CajaID int NOT NULL CONSTRAINT FK_CajeroCaja_Caja REFERENCES dbo.Caja,
    CONSTRAINT PK_CajeroCaja PRIMARY KEY(EmpleadoID,CajaID)
);
-- Una sola fila por cliente; CHECK exige exactamente una variante.
-- No se duplican nombres de personas en empresas ni documentos entre subtipos.
CREATE TABLE dbo.Cliente (
    ClienteID int NOT NULL CONSTRAINT PK_Cliente PRIMARY KEY,
    Celular varchar(15) NULL,
    Nombre nvarchar(80) NULL,
    Apellido nvarchar(100) NULL,
    DNI char(8) NULL,
    RUC char(11) NULL,
    RazonSocial nvarchar(150) NULL,
    FechaRegistro date NOT NULL,
    CONSTRAINT CK_Cliente_Variante CHECK (
        (DNI IS NOT NULL AND LEN(DNI)=8 AND DNI NOT LIKE '%[^0-9]%'
         AND Nombre IS NOT NULL AND LEN(LTRIM(RTRIM(Nombre)))>0
         AND Apellido IS NOT NULL AND LEN(LTRIM(RTRIM(Apellido)))>0
         AND RUC IS NULL AND RazonSocial IS NULL)
        OR
        (RUC IS NOT NULL AND LEN(RUC)=11 AND RUC NOT LIKE '%[^0-9]%'
         AND RazonSocial IS NOT NULL AND LEN(LTRIM(RTRIM(RazonSocial)))>0
         AND DNI IS NULL AND Nombre IS NULL AND Apellido IS NULL)
    ),
    CONSTRAINT CK_Cliente_Celular CHECK(Celular IS NULL OR (LEN(Celular) BETWEEN 7 AND 15 AND Celular NOT LIKE '%[^0-9]%'))
);
CREATE UNIQUE INDEX UX_Cliente_DNI ON dbo.Cliente(DNI) WHERE DNI IS NOT NULL;
CREATE UNIQUE INDEX UX_Cliente_RUC ON dbo.Cliente(RUC) WHERE RUC IS NOT NULL;
-- Producto con variantes exclusivas: las columnas no aplicables son NULL.
-- No se almacena un discriminador redundante; la variante se deriva de sus atributos.
CREATE TABLE dbo.Producto (
    ProductoID int NOT NULL CONSTRAINT PK_Producto PRIMARY KEY,
    SKU varchar(20) NOT NULL CONSTRAINT UQ_Producto_SKU UNIQUE,
    Nombre nvarchar(100) NOT NULL,
    CategoriaID int NOT NULL CONSTRAINT FK_Producto_Categoria REFERENCES dbo.Categoria,
    PrecioActual decimal(12,2) NOT NULL CONSTRAINT CK_Producto_Precio CHECK(PrecioActual > 0),
    TipoPlatoID int NULL CONSTRAINT FK_Producto_TipoPlato REFERENCES dbo.TipoPlato,
    MarcaID int NULL CONSTRAINT FK_Producto_Marca REFERENCES dbo.Marca,
    TemperaturaID int NULL CONSTRAINT FK_Producto_Temperatura REFERENCES dbo.TemperaturaServicio,
    VolumenML smallint NULL,
    Activo bit NOT NULL CONSTRAINT DF_Producto_Activo DEFAULT 1,
    CONSTRAINT CK_Producto_Variante CHECK (
       (TipoPlatoID IS NOT NULL AND MarcaID IS NULL AND TemperaturaID IS NULL AND VolumenML IS NULL)
       OR (TipoPlatoID IS NULL AND MarcaID IS NOT NULL AND TemperaturaID IS NOT NULL AND VolumenML IS NOT NULL AND VolumenML > 0)
    )
);
CREATE TABLE dbo.Proveedor (
    ProveedorID int NOT NULL CONSTRAINT PK_Proveedor PRIMARY KEY,
    RUC char(11) NOT NULL CONSTRAINT UQ_Proveedor_RUC UNIQUE,
    RazonSocial nvarchar(150) NOT NULL,
    CONSTRAINT CK_Proveedor_RUC CHECK(LEN(RUC)=11 AND RUC NOT LIKE '%[^0-9]%')
);
CREATE TABLE dbo.IngresoProducto (
    IngresoID int NOT NULL CONSTRAINT PK_IngresoProducto PRIMARY KEY,
    SucursalID int NOT NULL CONSTRAINT FK_Ingreso_Sucursal REFERENCES dbo.Sucursal,
    ProveedorID int NOT NULL CONSTRAINT FK_Ingreso_Proveedor REFERENCES dbo.Proveedor,
    EmpleadoID int NOT NULL CONSTRAINT FK_Ingreso_Empleado REFERENCES dbo.Empleado,
    Fecha date NOT NULL,
    Referencia varchar(30) NOT NULL,
    CONSTRAINT UQ_Ingreso_Referencia UNIQUE(ProveedorID, Referencia)
);
CREATE TABLE dbo.DetalleIngresoProducto (
    IngresoID int NOT NULL CONSTRAINT FK_DetalleIngreso_Ingreso REFERENCES dbo.IngresoProducto,
    Linea smallint NOT NULL,
    ProductoID int NOT NULL CONSTRAINT FK_DetalleIngreso_Producto REFERENCES dbo.Producto,
    Cantidad int NOT NULL CONSTRAINT CK_DetalleIngreso_Cantidad CHECK(Cantidad > 0),
    CostoUnitario decimal(12,2) NOT NULL CONSTRAINT CK_DetalleIngreso_Costo CHECK(CostoUnitario > 0),
    CONSTRAINT PK_DetalleIngreso PRIMARY KEY(IngresoID, Linea),
    CONSTRAINT CK_DetalleIngreso_Linea CHECK(Linea > 0)
);
CREATE TABLE dbo.PedidoVenta (
    PedidoID int NOT NULL CONSTRAINT PK_PedidoVenta PRIMARY KEY,
    FechaHora datetime2(0) NOT NULL,
    FechaCierre datetime2(0) NULL,
    SucursalID int NOT NULL CONSTRAINT FK_Pedido_Sucursal REFERENCES dbo.Sucursal,
    EmpleadoID int NOT NULL CONSTRAINT FK_Pedido_Empleado REFERENCES dbo.Empleado,
    ClienteID int NOT NULL CONSTRAINT FK_Pedido_Cliente REFERENCES dbo.Cliente,
    TipoPedidoID int NOT NULL CONSTRAINT FK_Pedido_Tipo REFERENCES dbo.TipoPedido,
    EstadoPedidoID int NOT NULL CONSTRAINT FK_Pedido_Estado REFERENCES dbo.EstadoPedido,
    Observaciones nvarchar(250) NULL,
    CONSTRAINT CK_Pedido_Cierre CHECK (
       (EstadoPedidoID=1 AND FechaCierre IS NULL) OR
       (EstadoPedidoID IN (2,3) AND FechaCierre IS NOT NULL AND FechaCierre>=FechaHora)
    )
);
CREATE TABLE dbo.DetallePedidoVenta (
    PedidoID int NOT NULL CONSTRAINT FK_DetallePedido_Pedido REFERENCES dbo.PedidoVenta,
    Linea smallint NOT NULL,
    ProductoID int NOT NULL CONSTRAINT FK_DetallePedido_Producto REFERENCES dbo.Producto,
    Cantidad smallint NOT NULL CONSTRAINT CK_DetallePedido_Cantidad CHECK(Cantidad > 0),
    PrecioUnitario decimal(12,2) NOT NULL CONSTRAINT CK_DetallePedido_Precio CHECK(PrecioUnitario > 0),
    Descuento decimal(12,2) NOT NULL CONSTRAINT DF_DetallePedido_Descuento DEFAULT 0,
    CostoUnitarioEstimado decimal(12,2) NOT NULL CONSTRAINT CK_DetallePedido_Costo CHECK(CostoUnitarioEstimado>=0),
    CONSTRAINT PK_DetallePedido PRIMARY KEY(PedidoID, Linea),
    CONSTRAINT CK_DetallePedido_Linea CHECK(Linea > 0),
    CONSTRAINT CK_DetallePedido_Descuento CHECK(Descuento>=0 AND Descuento < Cantidad*PrecioUnitario)
);
CREATE TABLE dbo.PedidoMesa (
    PedidoID int NOT NULL CONSTRAINT FK_PedidoMesa_Pedido REFERENCES dbo.PedidoVenta,
    MesaID int NOT NULL CONSTRAINT FK_PedidoMesa_Mesa REFERENCES dbo.Mesa,
    CONSTRAINT PK_PedidoMesa PRIMARY KEY(PedidoID,MesaID)
);
CREATE TABLE dbo.Delivery (
    PedidoID int NOT NULL CONSTRAINT PK_Delivery PRIMARY KEY CONSTRAINT FK_Delivery_Pedido REFERENCES dbo.PedidoVenta,
    RepartidorID int NOT NULL CONSTRAINT FK_Delivery_Empleado REFERENCES dbo.Empleado,
    VehiculoID int NOT NULL CONSTRAINT FK_Delivery_Vehiculo REFERENCES dbo.Vehiculo,
    DireccionEntrega nvarchar(200) NOT NULL,
    FechaSalida datetime2(0) NOT NULL,
    FechaEntrega datetime2(0) NULL,
    CargoEnvio decimal(10,2) NOT NULL CONSTRAINT CK_Delivery_Cargo CHECK(CargoEnvio>=0),
    CONSTRAINT CK_Delivery_Fechas CHECK(FechaEntrega IS NULL OR FechaEntrega>=FechaSalida)
);
-- Comprobante identifica la venta; Pago registra cada cobro (permite pago mixto).
CREATE TABLE dbo.ComprobantePago (
    ComprobanteID int NOT NULL CONSTRAINT PK_Comprobante PRIMARY KEY,
    PedidoID int NOT NULL CONSTRAINT UQ_Comprobante_Pedido UNIQUE CONSTRAINT FK_Comprobante_Pedido REFERENCES dbo.PedidoVenta,
    Serie varchar(8) NOT NULL,
    Numero int NOT NULL CONSTRAINT CK_Comprobante_Numero CHECK(Numero>0),
    FechaEmision datetime2(0) NOT NULL,
    CONSTRAINT UQ_Comprobante_Numero UNIQUE(Serie,Numero)
);
CREATE TABLE dbo.Pago (
    PagoID int NOT NULL CONSTRAINT PK_Pago PRIMARY KEY,
    ComprobanteID int NOT NULL CONSTRAINT FK_Pago_Comprobante REFERENCES dbo.ComprobantePago,
    MetodoPagoID int NOT NULL CONSTRAINT FK_Pago_Metodo REFERENCES dbo.MetodoPago,
    FechaHora datetime2(0) NOT NULL,
    Monto decimal(14,2) NOT NULL CONSTRAINT CK_Pago_Monto CHECK(Monto>0)
);

-- 2. Indices orientados a rangos temporales, joins y filtros analiticos.
CREATE INDEX IX_Pedido_Fecha ON dbo.PedidoVenta(FechaHora, SucursalID) INCLUDE(EstadoPedidoID,TipoPedidoID,ClienteID);
CREATE INDEX IX_Pedido_Cliente ON dbo.PedidoVenta(ClienteID, FechaHora);
CREATE INDEX IX_Pedido_Empleado ON dbo.PedidoVenta(EmpleadoID,FechaHora);
CREATE INDEX IX_Pedido_Sucursal ON dbo.PedidoVenta(SucursalID,FechaHora);
CREATE INDEX IX_Detalle_Producto ON dbo.DetallePedidoVenta(ProductoID,PedidoID) INCLUDE(Cantidad,PrecioUnitario,Descuento,CostoUnitarioEstimado);
CREATE INDEX IX_Producto_Categoria ON dbo.Producto(CategoriaID);
CREATE INDEX IX_Ingreso_Fecha ON dbo.IngresoProducto(Fecha,SucursalID);
CREATE INDEX IX_Ingreso_Proveedor ON dbo.IngresoProducto(ProveedorID,Fecha);
CREATE INDEX IX_Ingreso_Empleado ON dbo.IngresoProducto(EmpleadoID);
CREATE INDEX IX_Ingreso_Sucursal ON dbo.IngresoProducto(SucursalID);
CREATE INDEX IX_DetalleIngreso_Producto ON dbo.DetalleIngresoProducto(ProductoID,IngresoID);
CREATE INDEX IX_Pago_Comprobante ON dbo.Pago(ComprobanteID) INCLUDE(Monto,MetodoPagoID,FechaHora);
CREATE INDEX IX_Pago_Metodo ON dbo.Pago(MetodoPagoID,FechaHora);
CREATE INDEX IX_PedidoMesa_Mesa ON dbo.PedidoMesa(MesaID);
CREATE INDEX IX_Delivery_Repartidor ON dbo.Delivery(RepartidorID,FechaSalida);
CREATE INDEX IX_Delivery_Vehiculo ON dbo.Delivery(VehiculoID);

EXEC sys.sp_executesql N'CREATE VIEW dbo.vw_VentaDetalle AS
SELECT p.PedidoID,d.Linea,p.FechaHora,p.SucursalID,p.ClienteID,p.EmpleadoID,p.TipoPedidoID,
       d.ProductoID,pr.CategoriaID,d.Cantidad,d.PrecioUnitario,d.Descuento,
       CAST(d.Cantidad*d.PrecioUnitario AS decimal(16,2)) AS ImporteBruto,
       CAST(d.Cantidad*d.PrecioUnitario-d.Descuento AS decimal(16,2)) AS VentaNeta,
       CAST(d.Cantidad*d.CostoUnitarioEstimado AS decimal(16,2)) AS CostoEstimado,
       CAST(d.Cantidad*(d.PrecioUnitario-d.CostoUnitarioEstimado)-d.Descuento AS decimal(16,2)) AS MargenEstimado
FROM dbo.PedidoVenta p JOIN dbo.DetallePedidoVenta d ON d.PedidoID=p.PedidoID
JOIN dbo.Producto pr ON pr.ProductoID=d.ProductoID
WHERE p.EstadoPedidoID=2;';

EXEC sys.sp_executesql N'CREATE VIEW dbo.vw_TotalPedido AS
SELECT p.PedidoID,p.FechaHora,p.FechaCierre,p.SucursalID,p.ClienteID,p.EmpleadoID,p.TipoPedidoID,p.EstadoPedidoID,
       COALESCE(d.Unidades,0) AS Unidades,
       COALESCE(d.VentaProductos,0) AS VentaProductos,
       COALESCE(d.Descuento,0) AS Descuento,
       COALESCE(d.CostoEstimado,0) AS CostoEstimado,
       COALESCE(e.CargoEnvio,0) AS CargoEnvio,
       CAST(COALESCE(d.VentaProductos,0)+COALESCE(e.CargoEnvio,0) AS decimal(18,2)) AS TotalPedido,
       COALESCE(c.Cobrado,0) AS Cobrado,
       CAST(COALESCE(d.VentaProductos,0)+COALESCE(e.CargoEnvio,0)-COALESCE(c.Cobrado,0) AS decimal(18,2)) AS Saldo
FROM dbo.PedidoVenta p
LEFT JOIN (SELECT PedidoID,SUM(CONVERT(int,Cantidad)) AS Unidades,
  SUM(Cantidad*PrecioUnitario-Descuento) AS VentaProductos,SUM(Descuento) AS Descuento,
  SUM(Cantidad*CostoUnitarioEstimado) AS CostoEstimado
  FROM dbo.DetallePedidoVenta GROUP BY PedidoID) d ON d.PedidoID=p.PedidoID
LEFT JOIN dbo.Delivery e ON e.PedidoID=p.PedidoID
LEFT JOIN (SELECT cp.PedidoID,SUM(pg.Monto) AS Cobrado FROM dbo.ComprobantePago cp
  JOIN dbo.Pago pg ON pg.ComprobanteID=cp.ComprobanteID GROUP BY cp.PedidoID) c ON c.PedidoID=p.PedidoID;';

EXEC sys.sp_executesql N'CREATE VIEW dbo.vw_VentasMensuales AS
SELECT DATEFROMPARTS(YEAR(FechaHora),MONTH(FechaHora),1) AS Mes,SucursalID,TipoPedidoID,
       COUNT_BIG(*) AS Pedidos,SUM(Unidades) AS Unidades,
       SUM(VentaProductos) AS VentaProductos,SUM(CargoEnvio) AS CargosEnvio,
       SUM(TotalPedido) AS VentaTotal,SUM(Descuento) AS Descuentos,
       SUM(VentaProductos-CostoEstimado) AS MargenProductosEstimado,
       CAST(AVG(TotalPedido) AS decimal(18,2)) AS TicketPromedio
FROM dbo.vw_TotalPedido WHERE EstadoPedidoID=2
GROUP BY DATEFROMPARTS(YEAR(FechaHora),MONTH(FechaHora),1),SucursalID,TipoPedidoID;';

EXEC sys.sp_executesql N'CREATE VIEW dbo.vw_ComprasDetalle AS
SELECT i.IngresoID,d.Linea,i.Fecha,i.SucursalID,i.ProveedorID,d.ProductoID,d.Cantidad,d.CostoUnitario,
       CAST(d.Cantidad*d.CostoUnitario AS decimal(18,2)) AS ImporteCompra
FROM dbo.IngresoProducto i JOIN dbo.DetalleIngresoProducto d ON d.IngresoID=i.IngresoID;';

EXEC sys.sp_executesql N'CREATE VIEW dbo.vw_Entregas AS
SELECT d.PedidoID,p.FechaHora,p.SucursalID,d.RepartidorID,d.VehiculoID,d.CargoEnvio,
       d.FechaSalida,d.FechaEntrega,
       DATEDIFF(MINUTE,p.FechaHora,d.FechaSalida) AS MinutosPreparacion,
       DATEDIFF(MINUTE,d.FechaSalida,d.FechaEntrega) AS MinutosTransporte,
       DATEDIFF(MINUTE,p.FechaHora,d.FechaEntrega) AS MinutosTotales
FROM dbo.Delivery d JOIN dbo.PedidoVenta p ON p.PedidoID=d.PedidoID
WHERE p.EstadoPedidoID=2;';

EXEC sys.sp_executesql N'CREATE VIEW dbo.vw_ClientesRFM AS
SELECT c.ClienteID,COALESCE(c.RazonSocial,CONCAT(c.Nombre,N'' '',c.Apellido)) AS Cliente,
       CASE WHEN c.DNI IS NOT NULL THEN N''Natural'' ELSE N''Empresa'' END AS TipoCliente,
       MIN(p.FechaHora) AS PrimeraCompra,MAX(p.FechaHora) AS UltimaCompra,
       COUNT_BIG(p.PedidoID) AS Frecuencia,COALESCE(SUM(p.TotalPedido),0) AS ValorMonetario
FROM dbo.Cliente c LEFT JOIN dbo.vw_TotalPedido p ON p.ClienteID=c.ClienteID AND p.EstadoPedidoID=2
GROUP BY c.ClienteID,c.RazonSocial,c.Nombre,c.Apellido,c.DNI;';

EXEC sys.sp_executesql N'CREATE VIEW dbo.vw_Cobros AS
SELECT pg.PagoID,cp.PedidoID,pg.FechaHora,p.SucursalID,pg.MetodoPagoID,pg.Monto
FROM dbo.Pago pg JOIN dbo.ComprobantePago cp ON cp.ComprobanteID=pg.ComprobanteID
JOIN dbo.PedidoVenta p ON p.PedidoID=cp.PedidoID WHERE p.EstadoPedidoID=2;';

EXEC sys.sp_executesql N'CREATE TRIGGER dbo.TR_Pedido_Integridad ON dbo.PedidoVenta AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM deleted WHERE EstadoPedidoID<>1)
    THROW 51100,''Un pedido cerrado es historico e inmutable.'',1;
 IF EXISTS(SELECT 1 FROM inserted p JOIN dbo.Cliente c ON c.ClienteID=p.ClienteID
   JOIN dbo.Empleado e ON e.EmpleadoID=p.EmpleadoID JOIN dbo.Sucursal s ON s.SucursalID=p.SucursalID
   WHERE CONVERT(date,p.FechaHora)<c.FechaRegistro OR CONVERT(date,p.FechaHora)<e.FechaIngreso
      OR CONVERT(date,p.FechaHora)<s.FechaApertura)
    THROW 51101,''Pedido anterior al registro del cliente, ingreso del empleado o apertura.'',1;
 IF EXISTS(SELECT 1 FROM inserted p JOIN dbo.PedidoMesa pm ON pm.PedidoID=p.PedidoID
   JOIN dbo.Mesa m ON m.MesaID=pm.MesaID WHERE p.TipoPedidoID<>1 OR p.SucursalID<>m.SucursalID)
    THROW 51102,''Mesa incompatible con canal o sucursal.'',1;
 IF EXISTS(SELECT 1 FROM inserted p JOIN dbo.Delivery d ON d.PedidoID=p.PedidoID
   WHERE p.TipoPedidoID<>2 OR d.FechaSalida<p.FechaHora
   OR (p.FechaCierre IS NOT NULL AND d.FechaEntrega>p.FechaCierre))
    THROW 51103,''Entrega incompatible con el pedido o sus fechas.'',1;
 IF EXISTS(SELECT 1 FROM inserted p WHERE p.EstadoPedidoID=3 AND
   (EXISTS(SELECT 1 FROM dbo.ComprobantePago c WHERE c.PedidoID=p.PedidoID)
    OR EXISTS(SELECT 1 FROM dbo.Delivery d WHERE d.PedidoID=p.PedidoID)))
    THROW 51104,''Un pedido cancelado no puede tener comprobante ni entrega.'',1;
 IF EXISTS(SELECT 1 FROM inserted p JOIN dbo.vw_TotalPedido t ON t.PedidoID=p.PedidoID
   WHERE p.EstadoPedidoID=2 AND (t.Unidades=0 OR t.Saldo<>0
    OR NOT EXISTS(SELECT 1 FROM dbo.ComprobantePago c WHERE c.PedidoID=p.PedidoID)
    OR (p.TipoPedidoID=1 AND NOT EXISTS(SELECT 1 FROM dbo.PedidoMesa m WHERE m.PedidoID=p.PedidoID))
    OR (p.TipoPedidoID=2 AND NOT EXISTS(SELECT 1 FROM dbo.Delivery d WHERE d.PedidoID=p.PedidoID AND d.FechaEntrega IS NOT NULL))))
    THROW 51105,''Cierre rechazado: faltan detalles, cobros exactos, mesa o entrega.'',1;
 IF EXISTS(SELECT 1 FROM inserted p JOIN dbo.ComprobantePago c ON c.PedidoID=p.PedidoID
   LEFT JOIN dbo.Pago pg ON pg.ComprobanteID=c.ComprobanteID
   WHERE c.FechaEmision<p.FechaHora OR c.FechaEmision>p.FechaCierre
      OR pg.FechaHora<c.FechaEmision OR pg.FechaHora>p.FechaCierre)
    THROW 51106,''Fechas de comprobante o cobro incompatibles.'',1;
END;';

EXEC sys.sp_executesql N'CREATE TRIGGER dbo.TR_DetallePedidoVenta_Abierto ON dbo.DetallePedidoVenta AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 -- UPDLOCK/HOLDLOCK serializa ediciones de hijos y cierre del mismo pedido.
 IF EXISTS(SELECT 1 FROM dbo.PedidoVenta p WITH (UPDLOCK,HOLDLOCK)
   JOIN (SELECT PedidoID FROM inserted UNION SELECT PedidoID FROM deleted) x ON x.PedidoID=p.PedidoID
   WHERE p.EstadoPedidoID<>1)
   THROW 51110,''Los datos de un pedido cerrado no se pueden modificar.'',1;
END;';

EXEC sys.sp_executesql N'CREATE TRIGGER dbo.TR_PedidoMesa_Abierto ON dbo.PedidoMesa AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 -- UPDLOCK/HOLDLOCK serializa ediciones de hijos y cierre del mismo pedido.
 IF EXISTS(SELECT 1 FROM dbo.PedidoVenta p WITH (UPDLOCK,HOLDLOCK)
   JOIN (SELECT PedidoID FROM inserted UNION SELECT PedidoID FROM deleted) x ON x.PedidoID=p.PedidoID
   WHERE p.EstadoPedidoID<>1)
   THROW 51110,''Los datos de un pedido cerrado no se pueden modificar.'',1;
END;';

EXEC sys.sp_executesql N'CREATE TRIGGER dbo.TR_Delivery_Abierto ON dbo.Delivery AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 -- UPDLOCK/HOLDLOCK serializa ediciones de hijos y cierre del mismo pedido.
 IF EXISTS(SELECT 1 FROM dbo.PedidoVenta p WITH (UPDLOCK,HOLDLOCK)
   JOIN (SELECT PedidoID FROM inserted UNION SELECT PedidoID FROM deleted) x ON x.PedidoID=p.PedidoID
   WHERE p.EstadoPedidoID<>1)
   THROW 51110,''Los datos de un pedido cerrado no se pueden modificar.'',1;
END;';

EXEC sys.sp_executesql N'CREATE TRIGGER dbo.TR_ComprobantePago_Abierto ON dbo.ComprobantePago AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 -- UPDLOCK/HOLDLOCK serializa ediciones de hijos y cierre del mismo pedido.
 IF EXISTS(SELECT 1 FROM dbo.PedidoVenta p WITH (UPDLOCK,HOLDLOCK)
   JOIN (SELECT PedidoID FROM inserted UNION SELECT PedidoID FROM deleted) x ON x.PedidoID=p.PedidoID
   WHERE p.EstadoPedidoID<>1)
   THROW 51110,''Los datos de un pedido cerrado no se pueden modificar.'',1;
END;';

EXEC sys.sp_executesql N'CREATE TRIGGER dbo.TR_Pago_Abierto ON dbo.Pago AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM dbo.PedidoVenta p WITH (UPDLOCK,HOLDLOCK)
  JOIN dbo.ComprobantePago c ON c.PedidoID=p.PedidoID
  JOIN (SELECT ComprobanteID FROM inserted UNION SELECT ComprobanteID FROM deleted) x ON x.ComprobanteID=c.ComprobanteID
  WHERE p.EstadoPedidoID<>1)
   THROW 51111,''Los cobros de un pedido cerrado no se pueden modificar.'',1;
END;';

-- 3. Catalogos y registros originales corregidos. No se ejecuta el DDL original.

INSERT dbo.Categoria (CategoriaID,Nombre) VALUES
(N'1', N'Café Tradicional'),
(N'2', N'Café Premium'),
(N'3', N'Especialidad del Barista'),
(N'4', N'Cócteles Clásicos'),
(N'5', N'Cócteles de Autor'),
(N'6', N'Infusiones'),
(N'7', N'Sándwiches Especiales'),
(N'8', N'Sándwiches Clásicos'),
(N'9', N'Piqueos'),
(N'10', N'Criollos'),
(N'11', N'Bebidas'),
(N'12', N'Adicionales'),
(N'13', N'Desayunos'),
(N'14', N'Ensaladas'),
(N'15', N'Postres');

INSERT dbo.MetodoPago (MetodoPagoID,Nombre) VALUES
(N'1', N'Efectivo'),
(N'2', N'Visa'),
(N'3', N'Mastercard'),
(N'4', N'Yape'),
(N'5', N'Plin');

INSERT dbo.TipoPedido (TipoPedidoID,Nombre) VALUES
(N'1', N'En Mesa'),
(N'2', N'Delivery'),
(N'3', N'Para Llevar');

INSERT dbo.EstadoPedido (EstadoPedidoID,Nombre) VALUES
(N'1', N'Abierto'),
(N'2', N'Completado'),
(N'3', N'Cancelado');

INSERT dbo.Marca (MarcaID,Nombre) VALUES
(N'1', N'Anyli'),
(N'2', N'Coca Cola');

INSERT dbo.TemperaturaServicio (TemperaturaID,Nombre) VALUES
(N'1', N'Caliente'),
(N'2', N'Fría');

INSERT dbo.TipoPlato (TipoPlatoID,Nombre) VALUES
(N'1', N'Plato Fondo'),
(N'2', N'Sandwich'),
(N'3', N'Piqueo'),
(N'4', N'Desayuno'),
(N'5', N'Ensalada'),
(N'6', N'Postre'),
(N'7', N'Adicional');

INSERT dbo.Rol (RolID,Nombre) VALUES
(N'1', N'Administrador'),
(N'2', N'Mozo'),
(N'3', N'Cajero'),
(N'4', N'Repartidor'),
(N'5', N'Supervisor');

INSERT dbo.Sucursal (SucursalID,Nombre,Direccion,FechaApertura) VALUES
(N'1', N'Trujillo Centro', N'Av. España 100 - Trujillo', N'20230101'),
(N'2', N'Trujillo California', N'Av. Larco 200 - Trujillo', N'20230101'),
(N'3', N'Trujillo El Recreo', N'Av. América 300 - Trujillo', N'20230101');

INSERT dbo.Mesa (MesaID,SucursalID,Numero,Capacidad) VALUES
(N'1', N'1', N'1', N'2'),
(N'2', N'1', N'2', N'2'),
(N'3', N'1', N'3', N'2'),
(N'4', N'1', N'4', N'4'),
(N'5', N'1', N'5', N'4'),
(N'6', N'1', N'6', N'4'),
(N'7', N'1', N'7', N'4'),
(N'8', N'1', N'8', N'4'),
(N'9', N'1', N'9', N'6'),
(N'10', N'1', N'10', N'6'),
(N'11', N'1', N'11', N'6'),
(N'12', N'1', N'12', N'6'),
(N'13', N'1', N'13', N'8'),
(N'14', N'1', N'14', N'8'),
(N'15', N'1', N'15', N'8'),
(N'16', N'1', N'16', N'8'),
(N'17', N'1', N'17', N'10'),
(N'18', N'1', N'18', N'10'),
(N'19', N'1', N'19', N'10'),
(N'20', N'1', N'20', N'10'),
(N'21', N'2', N'1', N'2'),
(N'22', N'2', N'2', N'2'),
(N'23', N'2', N'3', N'2'),
(N'24', N'2', N'4', N'4'),
(N'25', N'2', N'5', N'4'),
(N'26', N'2', N'6', N'4'),
(N'27', N'2', N'7', N'4'),
(N'28', N'2', N'8', N'4'),
(N'29', N'2', N'9', N'6'),
(N'30', N'2', N'10', N'6'),
(N'31', N'2', N'11', N'6'),
(N'32', N'2', N'12', N'6'),
(N'33', N'2', N'13', N'8'),
(N'34', N'2', N'14', N'8'),
(N'35', N'2', N'15', N'8'),
(N'36', N'2', N'16', N'8'),
(N'37', N'2', N'17', N'10'),
(N'38', N'2', N'18', N'10'),
(N'39', N'2', N'19', N'10'),
(N'40', N'2', N'20', N'10'),
(N'41', N'3', N'1', N'2'),
(N'42', N'3', N'2', N'2'),
(N'43', N'3', N'3', N'2'),
(N'44', N'3', N'4', N'4'),
(N'45', N'3', N'5', N'4'),
(N'46', N'3', N'6', N'4'),
(N'47', N'3', N'7', N'4'),
(N'48', N'3', N'8', N'4'),
(N'49', N'3', N'9', N'6'),
(N'50', N'3', N'10', N'6'),
(N'51', N'3', N'11', N'6'),
(N'52', N'3', N'12', N'6'),
(N'53', N'3', N'13', N'8'),
(N'54', N'3', N'14', N'8'),
(N'55', N'3', N'15', N'8'),
(N'56', N'3', N'16', N'8'),
(N'57', N'3', N'17', N'10'),
(N'58', N'3', N'18', N'10'),
(N'59', N'3', N'19', N'10'),
(N'60', N'3', N'20', N'10');

INSERT dbo.Empleado (EmpleadoID,Nombre,Apellido,RolID,FechaIngreso) VALUES
(N'1', N'Carlos', N'Ramirez', N'1', N'20240110'),
(N'2', N'María', N'Lopez', N'2', N'20240115'),
(N'3', N'Luis', N'Fernandez', N'2', N'20240201'),
(N'4', N'Andrea', N'Torres', N'2', N'20240220'),
(N'5', N'Jorge', N'Vasquez', N'2', N'20240301'),
(N'6', N'Lucía', N'Paredes', N'2', N'20240305'),
(N'7', N'Ana', N'Gutierrez', N'3', N'20240108'),
(N'8', N'José', N'Campos', N'3', N'20240312'),
(N'9', N'Rosa', N'Rojas', N'3', N'20240405'),
(N'10', N'Diego', N'Torres', N'4', N'20240214'),
(N'11', N'Miguel', N'Sanchez', N'4', N'20240320'),
(N'12', N'Kevin', N'Flores', N'4', N'20240410'),
(N'13', N'Brayan', N'Silva', N'4', N'20240501'),
(N'14', N'Patricia', N'Reyes', N'5', N'20231010'),
(N'15', N'Fernando', N'Medina', N'1', N'20230601'),
(N'16', N'Elena', N'Soto', N'2', N'20230101'),
(N'17', N'Raúl', N'Vega', N'2', N'20230101'),
(N'18', N'Isabel', N'Díaz', N'2', N'20230101'),
(N'19', N'Hugo', N'Ríos', N'4', N'20230101'),
(N'20', N'Paola', N'Luna', N'4', N'20230101'),
(N'21', N'Marco', N'León', N'4', N'20230101');

INSERT dbo.Vehiculo (VehiculoID,Placa,Descripcion) VALUES
(N'101', N'SIM-101', N'Moto simulada'),
(N'102', N'SIM-102', N'Moto simulada'),
(N'103', N'SIM-103', N'Moto simulada'),
(N'104', N'SIM-104', N'Moto simulada'),
(N'105', N'SIM-105', N'Moto simulada'),
(N'106', N'SIM-106', N'Moto simulada'),
(N'107', N'SIM-107', N'Moto simulada');

INSERT dbo.Turno (TurnoID,Nombre) VALUES
(N'1', N'Mañana'),
(N'2', N'Tarde'),
(N'3', N'Noche');

INSERT dbo.EmpleadoTurno (EmpleadoID,TurnoID) VALUES
(N'2', N'1'),
(N'3', N'2'),
(N'4', N'3'),
(N'5', N'1'),
(N'6', N'2');

INSERT dbo.Caja (CajaID,SucursalID,Nombre) VALUES
(N'1', N'1', N'Caja 1'),
(N'2', N'1', N'Caja 2'),
(N'3', N'1', N'Caja 3');

INSERT dbo.CajeroCaja (EmpleadoID,CajaID) VALUES
(N'7', N'1'),
(N'8', N'2'),
(N'9', N'3');

INSERT dbo.Cliente (ClienteID,Celular,Nombre,Apellido,DNI,RUC,RazonSocial,FechaRegistro) VALUES
(N'1', N'987654321', N'Juan', N'Perez', N'74581236', NULL, NULL, N'20230101'),
(N'2', N'912345678', N'María', N'Garcia', N'70321458', NULL, NULL, N'20230101'),
(N'3', N'956123478', N'Luis', N'Ramirez', N'71894562', NULL, NULL, N'20230101'),
(N'4', N'945612378', N'Ana', N'Flores', N'72659841', NULL, NULL, N'20230101'),
(N'5', N'934561278', N'José', N'Vargas', N'73659874', NULL, NULL, N'20230101'),
(N'6', N'923451678', N'Pedro', N'Torres', N'74123698', NULL, NULL, N'20230101'),
(N'7', N'998877665', N'Lucía', N'Rojas', N'75896321', NULL, NULL, N'20230101'),
(N'8', N'987123654', N'Carmen', N'Soto', N'76985214', NULL, NULL, N'20230101'),
(N'9', N'965874123', N'Miguel', N'Castro', N'77896521', NULL, NULL, N'20230101'),
(N'10', N'954321876', N'Rosa', N'Mendoza', N'78123654', NULL, NULL, N'20230101'),
(N'11', N'943216587', N'Jorge', N'Alvarez', N'79236514', NULL, NULL, N'20230101'),
(N'12', N'932165478', N'Patricia', N'Quispe', N'70369852', NULL, NULL, N'20230101'),
(N'13', N'921654387', N'Kevin', N'Silva', N'71478523', NULL, NULL, N'20230101'),
(N'14', N'910987654', N'Brayan', N'Diaz', N'72589631', NULL, NULL, N'20230101'),
(N'15', N'900123456', N'Fernando', N'Navarro', N'73621498', NULL, NULL, N'20230101'),
(N'16', N'900000001', NULL, NULL, NULL, N'20601234561', N'Inversiones Norte SAC', N'20230101'),
(N'17', N'900000002', NULL, NULL, NULL, N'20601234562', N'Distribuidora El Sol SAC', N'20230101'),
(N'18', N'900000003', NULL, NULL, NULL, N'20601234563', N'Corporación Anyli SAC', N'20230101'),
(N'19', N'900000004', NULL, NULL, NULL, N'20601234564', N'Grupo Empresarial Perú SAC', N'20230101'),
(N'20', N'900000005', NULL, NULL, NULL, N'20601234565', N'Servicios Integrales Trujillo SAC', N'20230101');

INSERT dbo.Producto (ProductoID,SKU,Nombre,CategoriaID,PrecioActual,TipoPlatoID,MarcaID,TemperaturaID,VolumenML) VALUES
(N'1', N'PROD-001', N'Pollo a la Parrilla', N'10', N'32.90', N'1', NULL, NULL, NULL),
(N'2', N'PROD-002', N'Lomo Saltado', N'10', N'36.90', N'1', NULL, NULL, NULL),
(N'3', N'PROD-003', N'Arroz Chaufa de Pollo', N'10', N'28.90', N'1', NULL, NULL, NULL),
(N'4', N'PROD-004', N'Chaufa de Carne', N'10', N'31.90', N'1', NULL, NULL, NULL),
(N'5', N'PROD-005', N'Chicharrón de Pollo', N'10', N'24.90', N'1', NULL, NULL, NULL),
(N'6', N'PROD-006', N'Pollo Broaster', N'10', N'26.90', N'1', NULL, NULL, NULL),
(N'7', N'PROD-007', N'Bistec a lo Pobre', N'10', N'34.90', N'1', NULL, NULL, NULL),
(N'8', N'PROD-008', N'Milanesa de Pollo', N'10', N'29.90', N'1', NULL, NULL, NULL),
(N'9', N'PROD-009', N'Tallarín Saltado de Carne', N'10', N'33.90', N'1', NULL, NULL, NULL),
(N'10', N'PROD-010', N'Tallarín Verde con Pollo', N'10', N'31.90', N'1', NULL, NULL, NULL),
(N'11', N'PROD-011', N'Club Sandwich', N'7', N'32.90', N'2', NULL, NULL, NULL),
(N'12', N'PROD-012', N'Sándwich de Lomo Saltado', N'8', N'24.90', N'2', NULL, NULL, NULL),
(N'13', N'PROD-013', N'Mini Burgers', N'9', N'29.90', N'3', NULL, NULL, NULL),
(N'14', N'PROD-014', N'Alitas BBQ', N'9', N'29.90', N'3', NULL, NULL, NULL),
(N'15', N'PROD-015', N'Tequeños de Queso', N'9', N'12.90', N'3', NULL, NULL, NULL),
(N'16', N'PROD-016', N'Espresso', N'2', N'9.00', NULL, N'1', N'1', N'60'),
(N'17', N'PROD-017', N'Americano', N'2', N'10.00', NULL, N'1', N'1', N'240'),
(N'18', N'PROD-018', N'Capuccino', N'2', N'11.00', NULL, N'1', N'1', N'300'),
(N'19', N'PROD-019', N'Latte', N'2', N'12.50', NULL, N'1', N'1', N'300'),
(N'20', N'PROD-020', N'Mocaccino', N'2', N'14.00', NULL, N'1', N'1', N'300'),
(N'21', N'PROD-021', N'Vainilla Latte', N'3', N'14.00', NULL, N'1', N'1', N'300'),
(N'22', N'PROD-022', N'Caramel Latte', N'3', N'14.00', NULL, N'1', N'1', N'300'),
(N'23', N'PROD-023', N'Chococacao', N'3', N'14.00', NULL, N'1', N'1', N'300'),
(N'24', N'PROD-024', N'Mojito', N'4', N'22.90', NULL, N'1', N'2', N'350'),
(N'25', N'PROD-025', N'Pisco Sour', N'4', N'22.90', NULL, N'1', N'2', N'350'),
(N'26', N'PROD-026', N'Piña Colada', N'4', N'27.00', NULL, N'1', N'2', N'350'),
(N'27', N'PROD-027', N'Inka Kola', N'11', N'8.00', NULL, N'2', N'2', N'500'),
(N'28', N'PROD-028', N'Coca Cola', N'11', N'8.00', NULL, N'2', N'2', N'500'),
(N'29', N'PROD-029', N'Limonada', N'11', N'9.90', NULL, N'1', N'2', N'500'),
(N'30', N'PROD-030', N'Jugo de Maracuyá', N'11', N'13.90', NULL, N'1', N'2', N'500'),
(N'31', N'PROD-031', N'Café pasado', N'1', N'7.5', NULL, N'1', N'1', N'240'),
(N'32', N'PROD-032', N'Té de hierbaluisa', N'6', N'6.5', NULL, N'1', N'1', N'250'),
(N'33', N'PROD-033', N'Manzanilla', N'6', N'6.5', NULL, N'1', N'1', N'250'),
(N'34', N'PROD-034', N'Cóctel de maracuyá', N'5', N'25', NULL, N'1', N'2', N'350'),
(N'35', N'PROD-035', N'Desayuno continental', N'13', N'18', N'4', NULL, NULL, NULL),
(N'36', N'PROD-036', N'Desayuno americano', N'13', N'22', N'4', NULL, NULL, NULL),
(N'37', N'PROD-037', N'Ensalada César', N'14', N'24', N'5', NULL, NULL, NULL),
(N'38', N'PROD-038', N'Ensalada de quinua', N'14', N'23', N'5', NULL, NULL, NULL),
(N'39', N'PROD-039', N'Cheesecake de fresa', N'15', N'14', N'6', NULL, NULL, NULL),
(N'40', N'PROD-040', N'Torta de chocolate', N'15', N'13', N'6', NULL, NULL, NULL),
(N'41', N'PROD-041', N'Brownie', N'15', N'9', N'6', NULL, NULL, NULL),
(N'42', N'PROD-042', N'Porción de papas', N'12', N'8', N'7', NULL, NULL, NULL),
(N'43', N'PROD-043', N'Huevo adicional', N'12', N'3', N'7', NULL, NULL, NULL),
(N'44', N'PROD-044', N'Sándwich de pollo', N'8', N'16', N'2', NULL, NULL, NULL),
(N'45', N'PROD-045', N'Tostado de jamón y queso', N'8', N'14', N'2', NULL, NULL, NULL),
(N'46', N'PROD-046', N'Agua mineral', N'11', N'5', NULL, N'1', N'2', N'500'),
(N'47', N'PROD-047', N'Chocolate caliente', N'3', N'12', NULL, N'1', N'1', N'300'),
(N'48', N'PROD-048', N'Iced latte', N'3', N'14', NULL, N'1', N'2', N'400');

INSERT dbo.Proveedor (ProveedorID,RUC,RazonSocial) VALUES
(N'1', N'20800000001', N'Proveedor de simulación 1'),
(N'2', N'20800000002', N'Proveedor de simulación 2'),
(N'3', N'20800000003', N'Proveedor de simulación 3'),
(N'4', N'20800000004', N'Proveedor de simulación 4'),
(N'5', N'20800000005', N'Proveedor de simulación 5'),
(N'6', N'20800000006', N'Proveedor de simulación 6'),
(N'7', N'20800000007', N'Proveedor de simulación 7'),
(N'8', N'20800000008', N'Proveedor de simulación 8');

INSERT dbo.IngresoProducto (IngresoID,SucursalID,ProveedorID,EmpleadoID,Fecha,Referencia) VALUES
(N'1', N'1', N'1', N'15', N'20260401', N'ORIG-1'),
(N'2', N'1', N'1', N'15', N'20260408', N'ORIG-2'),
(N'3', N'1', N'1', N'15', N'20260415', N'ORIG-3'),
(N'4', N'1', N'1', N'15', N'20260422', N'ORIG-4'),
(N'5', N'1', N'1', N'15', N'20260502', N'ORIG-5'),
(N'6', N'1', N'1', N'15', N'20260510', N'ORIG-6'),
(N'7', N'1', N'1', N'15', N'20260518', N'ORIG-7'),
(N'8', N'1', N'1', N'15', N'20260603', N'ORIG-8'),
(N'9', N'1', N'1', N'15', N'20260612', N'ORIG-9'),
(N'10', N'1', N'1', N'15', N'20260624', N'ORIG-10');

INSERT dbo.DetalleIngresoProducto (IngresoID,Linea,ProductoID,Cantidad,CostoUnitario) VALUES
(N'1', N'1', N'1', N'30', N'22.50'),
(N'1', N'2', N'2', N'25', N'24.00'),
(N'1', N'3', N'3', N'40', N'18.00'),
(N'2', N'1', N'16', N'100', N'5.00'),
(N'2', N'2', N'17', N'80', N'6.00'),
(N'2', N'3', N'18', N'60', N'7.00'),
(N'3', N'1', N'11', N'25', N'20.00'),
(N'3', N'2', N'12', N'25', N'15.00'),
(N'3', N'3', N'13', N'20', N'18.00'),
(N'4', N'1', N'27', N'120', N'4.00'),
(N'4', N'2', N'28', N'120', N'4.00'),
(N'4', N'3', N'29', N'80', N'6.00'),
(N'5', N'1', N'4', N'30', N'21.00'),
(N'5', N'2', N'5', N'25', N'20.00'),
(N'6', N'1', N'6', N'25', N'23.00'),
(N'6', N'2', N'7', N'25', N'24.00'),
(N'7', N'1', N'8', N'40', N'5.50'),
(N'7', N'2', N'9', N'40', N'8.00'),
(N'8', N'1', N'14', N'30', N'18.00'),
(N'8', N'2', N'15', N'30', N'8.00'),
(N'9', N'1', N'20', N'50', N'7.00'),
(N'9', N'2', N'21', N'40', N'9.00'),
(N'10', N'1', N'24', N'30', N'14.00'),
(N'10', N'2', N'30', N'40', N'7.50');

INSERT dbo.PedidoVenta (PedidoID,FechaHora,SucursalID,EmpleadoID,ClienteID,TipoPedidoID,EstadoPedidoID,Observaciones) VALUES
(N'1', N'2026-04-02T08:30:00', N'1', N'2', N'1', N'1', N'1', N'Sin observaciones'),
(N'2', N'2026-04-04T12:15:00', N'1', N'3', N'2', N'2', N'1', N'Sin cebolla'),
(N'3', N'2026-04-05T13:00:00', N'1', N'4', N'3', N'1', N'1', N'Poco ají'),
(N'4', N'2026-04-08T18:20:00', N'1', N'5', N'4', N'3', N'1', NULL),
(N'5', N'2026-04-10T09:15:00', N'1', N'2', N'5', N'1', N'1', NULL),
(N'6', N'2026-04-13T20:00:00', N'1', N'6', N'6', N'2', N'1', N'Llamar al llegar'),
(N'7', N'2026-04-18T14:30:00', N'1', N'3', N'7', N'1', N'1', NULL),
(N'8', N'2026-04-21T17:40:00', N'1', N'4', N'8', N'3', N'1', N'Sin hielo'),
(N'9', N'2026-04-25T11:20:00', N'1', N'5', N'9', N'1', N'1', NULL),
(N'10', N'2026-04-29T19:10:00', N'1', N'2', N'10', N'2', N'1', N'Casa color blanco'),
(N'11', N'2026-05-03T08:20:00', N'1', N'3', N'11', N'1', N'1', N'Sin observaciones'),
(N'12', N'2026-05-05T13:15:00', N'1', N'5', N'12', N'2', N'1', N'Tocar timbre'),
(N'13', N'2026-05-08T12:40:00', N'1', N'2', N'13', N'1', N'1', N'Poco ají'),
(N'14', N'2026-05-10T18:30:00', N'1', N'6', N'14', N'3', N'1', NULL),
(N'15', N'2026-05-12T09:45:00', N'1', N'4', N'15', N'1', N'1', NULL),
(N'16', N'2026-05-15T20:10:00', N'1', N'2', N'16', N'2', N'1', N'Casa azul'),
(N'17', N'2026-05-18T13:50:00', N'1', N'5', N'17', N'1', N'1', NULL),
(N'18', N'2026-05-22T17:20:00', N'1', N'3', N'18', N'3', N'1', N'Sin azúcar'),
(N'19', N'2026-05-26T11:35:00', N'1', N'6', N'19', N'1', N'1', NULL),
(N'20', N'2026-05-30T19:30:00', N'1', N'4', N'20', N'2', N'1', N'Segundo piso'),
(N'21', N'2026-06-02T08:15:00', N'1', N'2', N'1', N'1', N'1', N'Sin observaciones'),
(N'22', N'2026-06-04T13:20:00', N'1', N'3', N'2', N'2', N'1', N'Llamar antes de llegar'),
(N'23', N'2026-06-07T12:30:00', N'1', N'4', N'3', N'1', N'1', N'Sin cebolla'),
(N'24', N'2026-06-10T18:10:00', N'1', N'5', N'4', N'3', N'1', NULL),
(N'25', N'2026-06-13T09:40:00', N'1', N'6', N'5', N'1', N'1', NULL),
(N'26', N'2026-06-16T20:15:00', N'1', N'2', N'6', N'2', N'1', N'Casa color verde'),
(N'27', N'2026-06-20T14:00:00', N'1', N'3', N'7', N'1', N'1', N'Sin azúcar'),
(N'28', N'2026-06-23T17:30:00', N'1', N'4', N'8', N'3', N'1', NULL),
(N'29', N'2026-06-27T11:45:00', N'1', N'5', N'9', N'1', N'1', NULL),
(N'30', N'2026-06-30T19:20:00', N'1', N'6', N'10', N'2', N'1', N'Departamento 302');

INSERT dbo.DetallePedidoVenta (PedidoID,Linea,ProductoID,Cantidad,PrecioUnitario,Descuento,CostoUnitarioEstimado) VALUES
(N'1', N'1', N'1', N'1', N'32.90', N'0', N'18.10'),
(N'1', N'2', N'27', N'2', N'8.00', N'0', N'4.40'),
(N'2', N'1', N'11', N'1', N'32.90', N'0', N'18.10'),
(N'2', N'2', N'28', N'1', N'8.00', N'0', N'4.40'),
(N'3', N'1', N'2', N'1', N'36.90', N'0', N'20.30'),
(N'3', N'2', N'17', N'1', N'10.00', N'0', N'5.50'),
(N'4', N'1', N'13', N'1', N'29.90', N'0', N'16.45'),
(N'4', N'2', N'24', N'2', N'22.90', N'0', N'12.60'),
(N'5', N'1', N'10', N'1', N'31.90', N'0', N'17.55'),
(N'5', N'2', N'19', N'1', N'12.50', N'0', N'6.88'),
(N'6', N'1', N'5', N'1', N'24.90', N'0', N'13.70'),
(N'6', N'2', N'29', N'2', N'9.90', N'0', N'5.45'),
(N'7', N'1', N'12', N'1', N'24.90', N'0', N'13.70'),
(N'7', N'2', N'27', N'1', N'8.00', N'0', N'4.40'),
(N'8', N'1', N'14', N'1', N'29.90', N'0', N'16.45'),
(N'8', N'2', N'28', N'1', N'8.00', N'0', N'4.40'),
(N'9', N'1', N'7', N'1', N'34.90', N'0', N'19.20'),
(N'9', N'2', N'18', N'1', N'11.00', N'0', N'6.05'),
(N'10', N'1', N'13', N'1', N'29.90', N'0', N'16.45'),
(N'10', N'2', N'30', N'2', N'13.90', N'0', N'7.65'),
(N'11', N'1', N'13', N'1', N'29.90', N'0', N'16.45'),
(N'11', N'2', N'16', N'2', N'9.00', N'0', N'4.95'),
(N'12', N'1', N'11', N'1', N'32.90', N'0', N'18.10'),
(N'12', N'2', N'27', N'2', N'8.00', N'0', N'4.40'),
(N'13', N'1', N'4', N'1', N'31.90', N'0', N'17.55'),
(N'13', N'2', N'19', N'1', N'12.50', N'0', N'6.88'),
(N'14', N'1', N'12', N'1', N'24.90', N'0', N'13.70'),
(N'14', N'2', N'25', N'1', N'22.90', N'0', N'12.60'),
(N'15', N'1', N'2', N'1', N'36.90', N'0', N'20.30'),
(N'15', N'2', N'17', N'1', N'10.00', N'0', N'5.50'),
(N'16', N'1', N'6', N'1', N'26.90', N'0', N'14.80'),
(N'16', N'2', N'30', N'2', N'13.90', N'0', N'7.65'),
(N'17', N'1', N'7', N'1', N'34.90', N'0', N'19.20'),
(N'17', N'2', N'18', N'1', N'11.00', N'0', N'6.05'),
(N'18', N'1', N'5', N'1', N'24.90', N'0', N'13.70'),
(N'18', N'2', N'20', N'1', N'14.00', N'0', N'7.70'),
(N'19', N'1', N'14', N'1', N'29.90', N'0', N'16.45'),
(N'19', N'2', N'28', N'1', N'8.00', N'0', N'4.40'),
(N'20', N'1', N'1', N'1', N'32.90', N'0', N'18.10'),
(N'20', N'2', N'29', N'2', N'9.90', N'0', N'5.45'),
(N'21', N'1', N'1', N'1', N'32.90', N'0', N'18.10'),
(N'21', N'2', N'27', N'1', N'8.00', N'0', N'4.40'),
(N'22', N'1', N'12', N'1', N'24.90', N'0', N'13.70'),
(N'22', N'2', N'30', N'1', N'13.90', N'0', N'7.65'),
(N'23', N'1', N'2', N'1', N'36.90', N'0', N'20.30'),
(N'23', N'2', N'18', N'1', N'11.00', N'0', N'6.05'),
(N'24', N'1', N'13', N'1', N'29.90', N'0', N'16.45'),
(N'24', N'2', N'24', N'1', N'22.90', N'0', N'12.60'),
(N'25', N'1', N'10', N'1', N'31.90', N'0', N'17.55'),
(N'25', N'2', N'19', N'1', N'12.50', N'0', N'6.88'),
(N'26', N'1', N'5', N'1', N'24.90', N'0', N'13.70'),
(N'26', N'2', N'29', N'2', N'9.90', N'0', N'5.45'),
(N'27', N'1', N'7', N'1', N'34.90', N'0', N'19.20'),
(N'27', N'2', N'17', N'1', N'10.00', N'0', N'5.50'),
(N'28', N'1', N'14', N'1', N'29.90', N'0', N'16.45'),
(N'28', N'2', N'28', N'1', N'8.00', N'0', N'4.40'),
(N'29', N'1', N'6', N'1', N'26.90', N'0', N'14.80'),
(N'29', N'2', N'20', N'1', N'14.00', N'0', N'7.70'),
(N'30', N'1', N'11', N'1', N'32.90', N'0', N'18.10'),
(N'30', N'2', N'27', N'2', N'8.00', N'0', N'4.40');

INSERT dbo.PedidoMesa (PedidoID,MesaID) VALUES
(N'1', N'3'),
(N'3', N'5'),
(N'5', N'2'),
(N'7', N'8'),
(N'9', N'4'),
(N'11', N'6'),
(N'13', N'7'),
(N'15', N'1'),
(N'17', N'10'),
(N'19', N'9'),
(N'21', N'11'),
(N'23', N'5'),
(N'25', N'2'),
(N'27', N'14'),
(N'29', N'7');

INSERT dbo.Delivery (PedidoID,RepartidorID,VehiculoID,DireccionEntrega,FechaSalida,FechaEntrega,CargoEnvio) VALUES
(N'2', N'10', N'101', N'Av. Larco 120', N'2026-04-04T12:55:00', N'2026-04-04T12:55:00', N'0'),
(N'6', N'11', N'102', N'Urb. California Mz A Lt 10', N'2026-04-13T20:40:00', N'2026-04-13T20:40:00', N'0'),
(N'10', N'12', N'103', N'Av. América Oeste 456', N'2026-04-29T19:50:00', N'2026-04-29T19:50:00', N'0'),
(N'12', N'13', N'104', N'Av. España 123', N'2026-05-05T13:50:00', N'2026-05-05T13:50:00', N'0'),
(N'16', N'10', N'101', N'Urb. El Recreo Mz B Lt 8', N'2026-05-15T20:45:00', N'2026-05-15T20:45:00', N'0'),
(N'20', N'11', N'102', N'Los Pinos 456', N'2026-05-30T20:05:00', N'2026-05-30T20:05:00', N'0'),
(N'22', N'12', N'103', N'Av. Larco 456', N'2026-06-04T14:00:00', N'2026-06-04T14:00:00', N'0'),
(N'26', N'13', N'104', N'Urb. Primavera Mz C Lt 5', N'2026-06-16T20:55:00', N'2026-06-16T20:55:00', N'0'),
(N'30', N'10', N'101', N'Las Flores 245', N'2026-06-30T20:00:00', N'2026-06-30T20:00:00', N'0');

-- El original no registra salida: se estima 20 minutos antes de la entrega.
UPDATE dbo.Delivery SET FechaSalida=DATEADD(MINUTE,-20,FechaEntrega);
INSERT dbo.ComprobantePago(ComprobanteID,PedidoID,Serie,Numero,FechaEmision)
SELECT PedidoID,PedidoID,'SIM-ORI',PedidoID,DATEADD(MINUTE,5,FechaHora) FROM dbo.PedidoVenta;

INSERT dbo.Pago (PagoID,ComprobanteID,MetodoPagoID,FechaHora,Monto) VALUES
(N'1', N'1', N'4', N'2026-04-02T08:30:00', N'48.90'),
(N'2', N'2', N'2', N'2026-04-04T12:15:00', N'40.90'),
(N'3', N'3', N'1', N'2026-04-05T13:00:00', N'46.90'),
(N'4', N'4', N'3', N'2026-04-08T18:20:00', N'75.70'),
(N'5', N'5', N'4', N'2026-04-10T09:15:00', N'44.40'),
(N'6', N'6', N'5', N'2026-04-13T20:00:00', N'44.70'),
(N'7', N'7', N'1', N'2026-04-18T14:30:00', N'32.90'),
(N'8', N'8', N'2', N'2026-04-21T17:40:00', N'37.90'),
(N'9', N'9', N'4', N'2026-04-25T11:20:00', N'45.90'),
(N'10', N'10', N'2', N'2026-04-29T19:10:00', N'57.70'),
(N'11', N'11', N'1', N'2026-05-03T08:20:00', N'47.90'),
(N'12', N'12', N'2', N'2026-05-05T13:15:00', N'48.90'),
(N'13', N'13', N'4', N'2026-05-08T12:40:00', N'44.40'),
(N'14', N'14', N'3', N'2026-05-10T18:30:00', N'47.80'),
(N'15', N'15', N'5', N'2026-05-12T09:45:00', N'46.90'),
(N'16', N'16', N'2', N'2026-05-15T20:10:00', N'54.70'),
(N'17', N'17', N'1', N'2026-05-18T13:50:00', N'45.90'),
(N'18', N'18', N'4', N'2026-05-22T17:20:00', N'38.90'),
(N'19', N'19', N'1', N'2026-05-26T11:35:00', N'37.90'),
(N'20', N'20', N'5', N'2026-05-30T19:30:00', N'52.70'),
(N'21', N'21', N'1', N'2026-06-02T08:15:00', N'40.90'),
(N'22', N'22', N'2', N'2026-06-04T13:20:00', N'38.80'),
(N'23', N'23', N'4', N'2026-06-07T12:30:00', N'47.90'),
(N'24', N'24', N'3', N'2026-06-10T18:10:00', N'52.80'),
(N'25', N'25', N'5', N'2026-06-13T09:40:00', N'44.40'),
(N'26', N'26', N'2', N'2026-06-16T20:15:00', N'44.70'),
(N'27', N'27', N'1', N'2026-06-20T14:00:00', N'44.90'),
(N'28', N'28', N'4', N'2026-06-23T17:30:00', N'37.90'),
(N'29', N'29', N'1', N'2026-06-27T11:45:00', N'40.90'),
(N'30', N'30', N'5', N'2026-06-30T19:20:00', N'48.90');

-- Se conserva el importe; el original solo trae fecha, se asigna la hora del comprobante.
UPDATE pg SET FechaHora=c.FechaEmision FROM dbo.Pago pg JOIN dbo.ComprobantePago c ON c.ComprobanteID=pg.ComprobanteID;
UPDATE dbo.PedidoVenta SET EstadoPedidoID=2,FechaCierre=DATEADD(MINUTE,60,FechaHora);

-- 4. Generador determinista. Semilla fija y fechas cerradas: resultados reproducibles.
CREATE TABLE #N(n int NOT NULL PRIMARY KEY);
;WITH dig(n) AS (SELECT n FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9))v(n))
INSERT #N SELECT a.n+10*b.n+100*c.n+1000*d.n FROM dig a CROSS JOIN dig b CROSS JOIN dig c CROSS JOIN dig d;

INSERT dbo.Cliente(ClienteID,Celular,Nombre,Apellido,DNI,RUC,RazonSocial,FechaRegistro)
SELECT n+21,CONVERT(varchar(15),910000000+n),
 CASE WHEN n%10<>0 THEN CHOOSE(n%12+1,N'Ana',N'Luis',N'María',N'Pedro',N'Lucía',N'José',N'Rosa',N'Miguel',N'Elena',N'Diego',N'Carla',N'Andrés') END,
 CASE WHEN n%10<>0 THEN CHOOSE((n/12)%10+1,N'García',N'Pérez',N'Quispe',N'Torres',N'Flores',N'Rojas',N'Soto',N'Díaz',N'Vega',N'Castro') END,
 CASE WHEN n%10<>0 THEN CONVERT(char(8),60000000+n) END,
 CASE WHEN n%10=0 THEN CONVERT(char(11),20900000000+CONVERT(bigint,n)) END,
 CASE WHEN n%10=0 THEN CONCAT(N'Empresa simulada ',n,N' SAC') END,
 DATEADD(DAY,n%330,CONVERT(date,'20230101',112))
FROM #N WHERE n<980;

-- Demanda variable por fin de semana, diciembre y crecimiento anual.
-- Cada sucursal genera 7 a 22 pedidos diarios; no usa RAND/CHECKSUM no reproducibles.
CREATE TABLE #Sim(PedidoID int PRIMARY KEY,Dia date NOT NULL,SucursalID int NOT NULL,
 TipoPedidoID int NOT NULL,Cancelado bit NOT NULL,Semilla bigint NOT NULL);
;WITH dias AS (
 SELECT DATEADD(DAY,n,CONVERT(date,'20240101',112)) AS Dia FROM #N
 WHERE n<DATEDIFF(DAY,CONVERT(date,'20240101',112),CONVERT(date,'20261001',112))
), base AS (
 SELECT d.Dia,s.SucursalID,k.n,
 CONVERT(bigint,DATEDIFF(DAY,CONVERT(date,'20240101',112),d.Dia))*1000+s.SucursalID*100+k.n AS z
 FROM dias d CROSS JOIN dbo.Sucursal s CROSS JOIN #N k
 WHERE k.n < 7+s.SucursalID+(YEAR(d.Dia)-2024)*2
 +CASE WHEN DATEDIFF(DAY,CONVERT(date,'19000101',112),d.Dia)%7 IN(5,6) THEN 4 ELSE 0 END
 +CASE WHEN MONTH(d.Dia)=12 THEN 4 ELSE 0 END
), hashed AS (
 SELECT *,((z*1103515245+12345)%2147483647) AS h FROM base
)
INSERT #Sim
SELECT 1000+CONVERT(int,ROW_NUMBER() OVER(ORDER BY Dia,SucursalID,n)),Dia,SucursalID,
 CASE WHEN h%100<50 THEN 1 WHEN h%100<80 THEN 2 ELSE 3 END,
 CASE WHEN (h/103)%100<4 THEN 1 ELSE 0 END,h FROM hashed;

INSERT dbo.PedidoVenta(PedidoID,FechaHora,SucursalID,EmpleadoID,ClienteID,TipoPedidoID,EstadoPedidoID,Observaciones)
SELECT PedidoID,DATEADD(MINUTE,480+CONVERT(int,(Semilla/7)%780),CAST(Dia AS datetime2(0))),
 SucursalID,15+SucursalID,
 CASE WHEN (Semilla/211)%100<35 THEN 21+CONVERT(int,(Semilla/307)%100)
 ELSE 21+CONVERT(int,(Semilla/307)%980) END,
 TipoPedidoID,1,CASE WHEN Cancelado=1 THEN N'Cancelación simulada antes del cobro' END
FROM #Sim;

-- Entre 1 y 5 lineas, mezcla de productos y cantidades 1 a 3.
INSERT dbo.DetallePedidoVenta(PedidoID,Linea,ProductoID,Cantidad,PrecioUnitario,Descuento,CostoUnitarioEstimado)
SELECT s.PedidoID,k.n+1,pr.ProductoID,v.Cantidad,v.Precio,
 CAST(ROUND(v.Cantidad*v.Precio*CASE WHEN (s.Semilla+k.n*29)%13=0 THEN 0.10 ELSE 0 END,2) AS decimal(12,2)),
 CAST(ROUND(v.Precio*(0.35+((s.Semilla/41+k.n)%26)/100.0),2) AS decimal(12,2))
FROM #Sim s JOIN #N k ON k.n<1+(s.Semilla/17)%5
CROSS APPLY(SELECT 1+CONVERT(int,(s.Semilla/31+k.n*13+MONTH(s.Dia)*3)%48) AS ProductoID) x
JOIN dbo.Producto pr ON pr.ProductoID=x.ProductoID
CROSS APPLY(SELECT CONVERT(smallint,1+(s.Semilla/23+k.n)%3) AS Cantidad,
 CAST(ROUND(pr.PrecioActual*(0.90+(YEAR(s.Dia)-2024)*0.05),2) AS decimal(12,2)) AS Precio) v;

INSERT dbo.PedidoMesa(PedidoID,MesaID)
SELECT s.PedidoID,(s.SucursalID-1)*20+1+CONVERT(int,(s.Semilla/53)%20) FROM #Sim s WHERE TipoPedidoID=1;
INSERT dbo.Delivery(PedidoID,RepartidorID,VehiculoID,DireccionEntrega,FechaSalida,FechaEntrega,CargoEnvio)
SELECT s.PedidoID,18+s.SucursalID,104+s.SucursalID,
 CONCAT(N'Calle simulada ',s.Semilla%80+1,N' N° ',s.Semilla%900+100),
 DATEADD(MINUTE,10+CONVERT(int,(s.Semilla/61)%16),p.FechaHora),
 DATEADD(MINUTE,30+CONVERT(int,(s.Semilla/71)%51),p.FechaHora),
 CONVERT(decimal(10,2),3+(s.Semilla/83)%6)
FROM #Sim s JOIN dbo.PedidoVenta p ON p.PedidoID=s.PedidoID WHERE s.TipoPedidoID=2 AND s.Cancelado=0;
INSERT dbo.ComprobantePago(ComprobanteID,PedidoID,Serie,Numero,FechaEmision)
SELECT s.PedidoID,s.PedidoID,CONCAT('SIM-0',s.SucursalID),s.PedidoID,DATEADD(MINUTE,5,p.FechaHora)
FROM #Sim s JOIN dbo.PedidoVenta p ON p.PedidoID=s.PedidoID WHERE s.Cancelado=0;

-- 20% de pagos mixtos. Segunda parte = total - primera: sin desfase de centimos.
INSERT dbo.Pago(PagoID,ComprobanteID,MetodoPagoID,FechaHora,Monto)
SELECT s.PedidoID*2,s.PedidoID,1+CONVERT(int,(s.Semilla/97)%5),c.FechaEmision,
 CASE WHEN s.Semilla%5=0 THEN CAST(ROUND(t.TotalPedido*0.60,2) AS decimal(14,2)) ELSE t.TotalPedido END
FROM #Sim s JOIN dbo.ComprobantePago c ON c.PedidoID=s.PedidoID
JOIN dbo.vw_TotalPedido t ON t.PedidoID=s.PedidoID;
INSERT dbo.Pago(PagoID,ComprobanteID,MetodoPagoID,FechaHora,Monto)
SELECT s.PedidoID*2+1,s.PedidoID,1+CONVERT(int,((s.Semilla/97)+1)%5),c.FechaEmision,
 t.TotalPedido-CAST(ROUND(t.TotalPedido*0.60,2) AS decimal(14,2))
FROM #Sim s JOIN dbo.ComprobantePago c ON c.PedidoID=s.PedidoID
JOIN dbo.vw_TotalPedido t ON t.PedidoID=s.PedidoID WHERE s.Semilla%5=0;

UPDATE p SET EstadoPedidoID=CASE WHEN s.Cancelado=1 THEN 3 ELSE 2 END,
 FechaCierre=DATEADD(MINUTE,CASE WHEN s.Cancelado=1 THEN 3 ELSE 90 END,p.FechaHora)
FROM dbo.PedidoVenta p JOIN #Sim s ON s.PedidoID=p.PedidoID;

-- Compras semanales de unidades terminadas/porciones a proveedores simulados.
-- No representa recetas, consumo de insumos ni un libro completo de inventario.
-- Reposicion planificada segun la demanda: cada lunes, cada sucursal compra solo los
-- productos que vende en esa semana (lunes a domingo), en la cantidad vendida mas un
-- 3% a 10% de stock de seguridad y merma (redondeo hacia arriba). El costo de compra
-- es el costo unitario estimado de esas mismas ventas, de modo que compras, costo de
-- ventas y margen quedan conciliados. Las ventas ya estan completas en este punto.
INSERT dbo.IngresoProducto(IngresoID,SucursalID,ProveedorID,EmpleadoID,Fecha,Referencia)
SELECT 1000+n*3+s.SucursalID,s.SucursalID,1+n%8,15,
 DATEADD(DAY,n*7,CONVERT(date,'20240101',112)),CONCAT('SIM-',n,'-',s.SucursalID)
FROM #N CROSS JOIN dbo.Sucursal s
WHERE n*7<DATEDIFF(DAY,CONVERT(date,'20240101',112),CONVERT(date,'20261001',112));
INSERT dbo.DetalleIngresoProducto(IngresoID,Linea,ProductoID,Cantidad,CostoUnitario)
SELECT i.IngresoID,CONVERT(smallint,v.ProductoID),v.ProductoID,
 CONVERT(int,CEILING(v.Unidades*(1.03+((i.IngresoID+v.ProductoID)%8)/100.0))),
 CAST(ROUND(v.CostoTotal/v.Unidades,2) AS decimal(12,2))
FROM dbo.IngresoProducto i
CROSS APPLY(
 SELECT d.ProductoID,SUM(CONVERT(int,d.Cantidad)) AS Unidades,
  SUM(CONVERT(decimal(18,2),d.Cantidad*d.CostoUnitarioEstimado)) AS CostoTotal
 FROM dbo.PedidoVenta p JOIN dbo.DetallePedidoVenta d ON d.PedidoID=p.PedidoID
 WHERE p.SucursalID=i.SucursalID AND p.EstadoPedidoID=2
  AND p.FechaHora>=CAST(i.Fecha AS datetime2(0))
  AND p.FechaHora<DATEADD(DAY,7,CAST(i.Fecha AS datetime2(0)))
 GROUP BY d.ProductoID) v
WHERE i.IngresoID>=1000;

-- 5. Aserciones ejecutables: cualquier fallo revierte esquema y datos.
IF (SELECT COUNT(*) FROM dbo.Cliente)<>1000 OR (SELECT COUNT(*) FROM dbo.Producto)<>48
 THROW 51200,'Conteo inesperado de clientes/productos.',1;
IF (SELECT COUNT(*) FROM dbo.PedidoVenta WHERE PedidoID<=30)<>30
 THROW 51201,'Faltan pedidos originales.',1;
IF EXISTS(SELECT 1 FROM dbo.vw_TotalPedido WHERE EstadoPedidoID=2 AND (Saldo<>0 OR TotalPedido<=0 OR Unidades=0))
 THROW 51202,'Ventas completadas con saldo o sin detalle.',1;
IF EXISTS(SELECT 1 FROM dbo.PedidoVenta p JOIN dbo.ComprobantePago c ON c.PedidoID=p.PedidoID WHERE p.EstadoPedidoID=3)
 THROW 51203,'Pedido cancelado con comprobante.',1;
IF EXISTS(SELECT 1 FROM dbo.PedidoMesa pm JOIN dbo.PedidoVenta p ON p.PedidoID=pm.PedidoID
 JOIN dbo.Mesa m ON m.MesaID=pm.MesaID WHERE p.TipoPedidoID<>1 OR p.SucursalID<>m.SucursalID)
 THROW 51204,'Mesa de otra sucursal o canal.',1;
IF EXISTS(SELECT 1 FROM dbo.Delivery d JOIN dbo.PedidoVenta p ON p.PedidoID=d.PedidoID
 JOIN dbo.Empleado e ON e.EmpleadoID=d.RepartidorID WHERE p.TipoPedidoID<>2 OR e.RolID<>4
 OR d.FechaSalida<p.FechaHora OR d.FechaEntrega>p.FechaCierre OR CONVERT(date,d.FechaSalida)<e.FechaIngreso)
 THROW 51205,'Inconsistencia en entregas.',1;
IF EXISTS(SELECT 1 FROM dbo.IngresoProducto i JOIN dbo.Empleado e ON e.EmpleadoID=i.EmpleadoID
 JOIN dbo.Sucursal s ON s.SucursalID=i.SucursalID WHERE i.Fecha<e.FechaIngreso OR i.Fecha<s.FechaApertura)
 THROW 51206,'Compra anterior al ingreso del empleado o apertura.',1;
IF (SELECT SUM(TotalPedido) FROM dbo.vw_TotalPedido WHERE EstadoPedidoID=2)
 <> (SELECT SUM(Monto) FROM dbo.Pago)
 THROW 51207,'La suma de ventas y la de cobros difieren.',1;
IF (SELECT COUNT(DISTINCT DATEFROMPARTS(YEAR(FechaHora),MONTH(FechaHora),1)) FROM dbo.PedidoVenta)<>33
 THROW 51208,'La simulacion no cubre los 33 meses previstos.',1;
-- Coherencia compras/ventas: cada compra semanal cubre lo vendido de cada producto
-- en esa sucursal y semana, y lo comprado (a costo) no supera lo vendido.
IF EXISTS(SELECT 1 FROM dbo.IngresoProducto i
 JOIN dbo.PedidoVenta p ON p.SucursalID=i.SucursalID AND p.EstadoPedidoID=2
  AND p.FechaHora>=CAST(i.Fecha AS datetime2(0))
  AND p.FechaHora<DATEADD(DAY,7,CAST(i.Fecha AS datetime2(0)))
 JOIN dbo.DetallePedidoVenta d ON d.PedidoID=p.PedidoID
 LEFT JOIN dbo.DetalleIngresoProducto di ON di.IngresoID=i.IngresoID AND di.ProductoID=d.ProductoID
 WHERE i.IngresoID>=1000
 GROUP BY i.IngresoID,d.ProductoID
 HAVING SUM(CONVERT(int,d.Cantidad))>MAX(COALESCE(di.Cantidad,0)))
 THROW 51209,'Una compra semanal no cubre lo vendido.',1;
IF (SELECT SUM(ImporteCompra) FROM dbo.vw_ComprasDetalle)
 >= (SELECT SUM(VentaProductos) FROM dbo.vw_TotalPedido WHERE EstadoPedidoID=2)
 THROW 51210,'Las compras superan a las ventas.',1;
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;

COMMIT TRANSACTION;
DROP TABLE #N;
DROP TABLE #Sim;
DROP TABLE #Cafeteria_Instalacion;
PRINT N'Instalacion completada: Cafeteria. Restricciones y conciliaciones verificadas.';
SELECT N'Clientes' AS Tabla,COUNT_BIG(*) AS Filas FROM dbo.Cliente
UNION ALL SELECT N'Productos',COUNT_BIG(*) FROM dbo.Producto
UNION ALL SELECT N'Pedidos',COUNT_BIG(*) FROM dbo.PedidoVenta
UNION ALL SELECT N'Detalles de venta',COUNT_BIG(*) FROM dbo.DetallePedidoVenta
UNION ALL SELECT N'Comprobantes',COUNT_BIG(*) FROM dbo.ComprobantePago
UNION ALL SELECT N'Pagos',COUNT_BIG(*) FROM dbo.Pago
UNION ALL SELECT N'Entregas',COUNT_BIG(*) FROM dbo.Delivery
UNION ALL SELECT N'Ingresos de producto',COUNT_BIG(*) FROM dbo.IngresoProducto
UNION ALL SELECT N'Detalles de ingreso',COUNT_BIG(*) FROM dbo.DetalleIngresoProducto;
SELECT MIN(FechaHora) AS PrimeraOperacion,MAX(FechaHora) AS UltimaOperacion,
 SUM(CASE WHEN EstadoPedidoID=2 THEN TotalPedido ELSE 0 END) AS TotalVendido,
 SUM(Cobrado) AS TotalCobrado FROM dbo.vw_TotalPedido;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
/* Consultas de ejemplo (opcionales, ejecutar despues de instalar):
SELECT * FROM dbo.vw_VentasMensuales ORDER BY Mes,SucursalID,TipoPedidoID;
SELECT TOP(10) pr.Nombre,SUM(v.VentaNeta) AS Venta,SUM(v.MargenEstimado) AS MargenEstimado
FROM dbo.vw_VentaDetalle v JOIN dbo.Producto pr ON pr.ProductoID=v.ProductoID
GROUP BY pr.ProductoID,pr.Nombre ORDER BY Venta DESC;
-- Recencia respecto al fin del periodo simulado; no depende del reloj del servidor.
SELECT *,DATEDIFF(DAY,UltimaCompra,CONVERT(date,'20261001',112)) AS RecenciaDias
FROM dbo.vw_ClientesRFM ORDER BY ValorMonetario DESC;
SELECT SucursalID,AVG(CONVERT(decimal(10,2),MinutosTotales)) AS MinutosPromedio
FROM dbo.vw_Entregas GROUP BY SucursalID;
*/
