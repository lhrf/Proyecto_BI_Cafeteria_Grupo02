USE master;
GO
SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;
IF @@TRANCOUNT <> 0
    THROW 52000, 'Ejecute sin transacciones pendientes.', 1;
DROP TABLE IF EXISTS #DM_Cafeteria_Instalacion;
IF DB_ID(N'DM_Cafeteria') IS NOT NULL
    THROW 52001, 'DM_Cafeteria ya existe. No se modifico.', 1;
EXEC(N'CREATE DATABASE [DM_Cafeteria];');
EXEC(N'ALTER DATABASE [DM_Cafeteria] SET COMPATIBILITY_LEVEL = 160;');
CREATE TABLE #DM_Cafeteria_Instalacion(DatabaseID int NOT NULL);
INSERT #DM_Cafeteria_Instalacion VALUES(DB_ID(N'DM_Cafeteria'));
GO
USE DM_Cafeteria;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
IF DB_NAME() <> N'DM_Cafeteria'
   OR OBJECT_ID('tempdb..#DM_Cafeteria_Instalacion') IS NULL
    THROW 52002, 'Ejecute el archivo completo: no se autorizo esta instalacion.', 1;
IF NOT EXISTS(SELECT 1 FROM #DM_Cafeteria_Instalacion WHERE DatabaseID=DB_ID())
    THROW 52003, 'La base actual no coincide con la base creada.', 1;

BEGIN TRY
BEGIN TRANSACTION;

-- 1. Metadatos de ejecucion. Tiempos tecnicos en UTC.
-- UltimaFechaCarga es una marca del ORIGEN, no el reloj de la ejecucion.
-- Un error conserva la marca anterior; solo OK puede avanzar la marca.
CREATE TABLE dbo.ETL_Control (
    IdControl bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ETL_Control PRIMARY KEY,
    Proceso nvarchar(128) NOT NULL,
    FechaInicio datetime2(3) NOT NULL CONSTRAINT DF_ETL_Inicio DEFAULT SYSUTCDATETIME(),
    FechaFin datetime2(3) NULL,
    UltimaFechaCarga datetime2(0) NULL,
    Estado varchar(12) NOT NULL CONSTRAINT DF_ETL_Estado DEFAULT 'EN_EJECUCION',
    FilasProcesadas bigint NOT NULL CONSTRAINT DF_ETL_Filas DEFAULT 0,
    NumeroError int NULL,
    Mensaje nvarchar(4000) NULL,
    CONSTRAINT CK_ETL_Proceso CHECK(LEN(LTRIM(RTRIM(Proceso)))>0),
    CONSTRAINT CK_ETL_Filas CHECK(FilasProcesadas>=0),
    CONSTRAINT CK_ETL_Estado CHECK(
       (Estado='EN_EJECUCION' AND FechaFin IS NULL AND NumeroError IS NULL)
       OR (Estado='OK' AND FechaFin IS NOT NULL AND FechaFin>=FechaInicio AND NumeroError IS NULL)
       OR (Estado='ERROR' AND FechaFin IS NOT NULL AND FechaFin>=FechaInicio
           AND Mensaje IS NOT NULL AND LEN(LTRIM(RTRIM(Mensaje)))>0)
    )
);
CREATE UNIQUE INDEX UX_ETL_ProcesoActivo ON dbo.ETL_Control(Proceso)
    WHERE Estado='EN_EJECUCION';
CREATE INDEX IX_ETL_ProcesoHistorial ON dbo.ETL_Control(Proceso,IdControl DESC)
    INCLUDE(Estado,UltimaFechaCarga,FechaInicio,FechaFin);

-- 2. Dimensiones planas: claves sustitutas + claves naturales para futuro ETL.
CREATE TABLE dbo.DimTiempo (
    TiempoKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimTiempo PRIMARY KEY,
    Fecha date NOT NULL CONSTRAINT UQ_DimTiempo_Fecha UNIQUE,
    Anio AS CONVERT(smallint,YEAR(Fecha)) PERSISTED,
    Semestre AS CONVERT(tinyint,(MONTH(Fecha)+5)/6) PERSISTED,
    Trimestre AS CONVERT(tinyint,DATEPART(QUARTER,Fecha)) PERSISTED,
    Mes AS CONVERT(tinyint,MONTH(Fecha)) PERSISTED,
    AnioMes AS (YEAR(Fecha)*100+MONTH(Fecha)) PERSISTED,
    -- Semana ISO 8601 (lunes); el ano ISO puede diferir del ano calendario.
    NumeroSemana AS CONVERT(tinyint,DATEPART(ISO_WEEK,Fecha)) PERSISTED,
    AnioSemanaISO AS CONVERT(smallint,CASE
      WHEN MONTH(Fecha)=1 AND DATEPART(ISO_WEEK,Fecha)>=52 THEN YEAR(Fecha)-1
      WHEN MONTH(Fecha)=12 AND DATEPART(ISO_WEEK,Fecha)=1 THEN YEAR(Fecha)+1
      ELSE YEAR(Fecha) END) PERSISTED,
    AnioTrimestre AS CONVERT(char(7),RIGHT('0000'+CONVERT(varchar(4),YEAR(Fecha)),4)
      +'-T'+CONVERT(char(1),DATEPART(QUARTER,Fecha))) PERSISTED,
    AnioMesNombre AS CONVERT(nvarchar(17),RIGHT('0000'+CONVERT(varchar(4),YEAR(Fecha)),4)+N' - '+
      CASE MONTH(Fecha)
      WHEN 1 THEN N'Enero' WHEN 2 THEN N'Febrero' WHEN 3 THEN N'Marzo'
      WHEN 4 THEN N'Abril' WHEN 5 THEN N'Mayo' WHEN 6 THEN N'Junio'
      WHEN 7 THEN N'Julio' WHEN 8 THEN N'Agosto' WHEN 9 THEN N'Septiembre'
      WHEN 10 THEN N'Octubre' WHEN 11 THEN N'Noviembre' WHEN 12 THEN N'Diciembre' END) PERSISTED,
    MesCorto AS CONVERT(nchar(3),CASE MONTH(Fecha)
      WHEN 1 THEN N'Ene' WHEN 2 THEN N'Feb' WHEN 3 THEN N'Mar'
      WHEN 4 THEN N'Abr' WHEN 5 THEN N'May' WHEN 6 THEN N'Jun'
      WHEN 7 THEN N'Jul' WHEN 8 THEN N'Ago' WHEN 9 THEN N'Sep'
      WHEN 10 THEN N'Oct' WHEN 11 THEN N'Nov' WHEN 12 THEN N'Dic' END) PERSISTED,
    NombreMes AS CONVERT(nvarchar(10),CASE MONTH(Fecha)
      WHEN 1 THEN N'Enero' WHEN 2 THEN N'Febrero' WHEN 3 THEN N'Marzo'
      WHEN 4 THEN N'Abril' WHEN 5 THEN N'Mayo' WHEN 6 THEN N'Junio'
      WHEN 7 THEN N'Julio' WHEN 8 THEN N'Agosto' WHEN 9 THEN N'Septiembre'
      WHEN 10 THEN N'Octubre' WHEN 11 THEN N'Noviembre' WHEN 12 THEN N'Diciembre' END) PERSISTED,
    DiaMes AS CONVERT(tinyint,DAY(Fecha)) PERSISTED,
    -- 0001-01-01 fue lunes; no depende de DATEFIRST ni LANGUAGE.
    DiaSemana AS CONVERT(tinyint,DATEDIFF(DAY,CONVERT(date,'00010101',112),Fecha)%7+1) PERSISTED,
    NombreDia AS CONVERT(nvarchar(10),CASE DATEDIFF(DAY,CONVERT(date,'00010101',112),Fecha)%7
      WHEN 0 THEN N'Lunes' WHEN 1 THEN N'Martes' WHEN 2 THEN N'Miércoles'
      WHEN 3 THEN N'Jueves' WHEN 4 THEN N'Viernes' WHEN 5 THEN N'Sábado'
      WHEN 6 THEN N'Domingo' END) PERSISTED,
    EsFinSemana AS CONVERT(bit,CASE WHEN DATEDIFF(DAY,CONVERT(date,'00010101',112),Fecha)%7>=5 THEN 1 ELSE 0 END) PERSISTED
);

CREATE TABLE dbo.DimProducto (
    ProductoKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProducto PRIMARY KEY,
    ProductoIDOrigen int NOT NULL CONSTRAINT UQ_DimProducto_Origen UNIQUE,
    SKU varchar(20) NOT NULL CONSTRAINT UQ_DimProducto_SKU UNIQUE,
    NombreProducto nvarchar(100) NOT NULL,
    CategoriaIDOrigen int NOT NULL,
    Categoria nvarchar(80) NOT NULL,
    TipoProducto varchar(6) NOT NULL,
    TipoPlatoIDOrigen int NULL,
    TipoPlato nvarchar(50) NULL,
    MarcaIDOrigen int NULL,
    Marca nvarchar(80) NULL,
    TemperaturaIDOrigen int NULL,
    Temperatura nvarchar(30) NULL,
    VolumenML smallint NULL,
    Activo bit NOT NULL,
    CONSTRAINT CK_DimProducto_Variante CHECK(
      (TipoProducto='PLATO' AND TipoPlatoIDOrigen IS NOT NULL AND TipoPlato IS NOT NULL
       AND MarcaIDOrigen IS NULL AND Marca IS NULL AND TemperaturaIDOrigen IS NULL
       AND Temperatura IS NULL AND VolumenML IS NULL)
      OR (TipoProducto='BEBIDA' AND TipoPlatoIDOrigen IS NULL AND TipoPlato IS NULL
       AND MarcaIDOrigen IS NOT NULL AND Marca IS NOT NULL AND TemperaturaIDOrigen IS NOT NULL
       AND Temperatura IS NOT NULL AND VolumenML IS NOT NULL AND VolumenML>0)
    )
);
CREATE INDEX IX_DimProducto_Categoria ON dbo.DimProducto(CategoriaIDOrigen,ProductoKey);

CREATE TABLE dbo.DimCliente (
    ClienteKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCliente PRIMARY KEY,
    ClienteIDOrigen int NOT NULL CONSTRAINT UQ_DimCliente_Origen UNIQUE,
    NombreCliente nvarchar(181) NOT NULL,
    TipoCliente varchar(7) NOT NULL,
    FechaRegistro date NOT NULL,
    CONSTRAINT CK_DimCliente_Tipo CHECK(TipoCliente IN('NATURAL','EMPRESA')),
    CONSTRAINT CK_DimCliente_Nombre CHECK(LEN(LTRIM(RTRIM(NombreCliente)))>0)
);
CREATE TABLE dbo.DimSucursal (
    SucursalKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimSucursal PRIMARY KEY,
    SucursalIDOrigen int NOT NULL CONSTRAINT UQ_DimSucursal_Origen UNIQUE,
    NombreSucursal nvarchar(80) NOT NULL,
    Direccion nvarchar(200) NOT NULL,
    FechaApertura date NOT NULL
);
CREATE TABLE dbo.DimEmpleado (
    EmpleadoKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimEmpleado PRIMARY KEY,
    EmpleadoIDOrigen int NOT NULL CONSTRAINT UQ_DimEmpleado_Origen UNIQUE,
    Nombre nvarchar(80) NOT NULL,
    Apellido nvarchar(100) NOT NULL,
    RolIDOrigen int NOT NULL,
    Rol nvarchar(40) NOT NULL,
    FechaIngreso date NOT NULL,
    Activo bit NOT NULL
);
CREATE TABLE dbo.DimTipoPedido (
    TipoPedidoKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimTipoPedido PRIMARY KEY,
    TipoPedidoIDOrigen int NOT NULL CONSTRAINT UQ_DimTipoPedido_Origen UNIQUE,
    NombreTipoPedido nvarchar(40) NOT NULL
);

-- 3. Hecho atomico. Solo ventas completadas: no hace falta una dimension Estado
-- cuyo valor seria siempre Completado. El futuro ETL aplicara ese filtro.
CREATE TABLE dbo.FactVenta (
    VentaKey bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactVenta PRIMARY KEY,
    TiempoKey int NOT NULL CONSTRAINT FK_FactVenta_Tiempo REFERENCES dbo.DimTiempo(TiempoKey),
    ProductoKey int NOT NULL CONSTRAINT FK_FactVenta_Producto REFERENCES dbo.DimProducto(ProductoKey),
    ClienteKey int NOT NULL CONSTRAINT FK_FactVenta_Cliente REFERENCES dbo.DimCliente(ClienteKey),
    SucursalKey int NOT NULL CONSTRAINT FK_FactVenta_Sucursal REFERENCES dbo.DimSucursal(SucursalKey),
    EmpleadoKey int NOT NULL CONSTRAINT FK_FactVenta_Empleado REFERENCES dbo.DimEmpleado(EmpleadoKey),
    TipoPedidoKey int NOT NULL CONSTRAINT FK_FactVenta_TipoPedido REFERENCES dbo.DimTipoPedido(TipoPedidoKey),
    PedidoIDOrigen int NOT NULL,
    LineaOrigen smallint NOT NULL,
    HoraPedido time(0) NOT NULL,
    Cantidad smallint NOT NULL,
    PrecioUnitario decimal(12,2) NOT NULL,
    DescuentoImporte decimal(12,2) NOT NULL,
    CostoUnitarioEstimado decimal(12,2) NOT NULL,
    ImporteBruto AS CONVERT(decimal(18,2),Cantidad*PrecioUnitario) PERSISTED,
    VentaNeta AS CONVERT(decimal(18,2),Cantidad*PrecioUnitario-DescuentoImporte) PERSISTED,
    CostoTotalEstimado AS CONVERT(decimal(18,2),Cantidad*CostoUnitarioEstimado) PERSISTED,
    MargenEstimado AS CONVERT(decimal(18,2),Cantidad*(PrecioUnitario-CostoUnitarioEstimado)-DescuentoImporte) PERSISTED,
    IdControlCarga bigint NOT NULL CONSTRAINT FK_FactVenta_Control REFERENCES dbo.ETL_Control(IdControl),
    FechaCargaUTC datetime2(3) NOT NULL CONSTRAINT DF_FactVenta_Carga DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_FactVenta_Origen UNIQUE(PedidoIDOrigen,LineaOrigen),
    CONSTRAINT CK_FactVenta_Linea CHECK(LineaOrigen>0),
    CONSTRAINT CK_FactVenta_Cantidad CHECK(Cantidad>0),
    CONSTRAINT CK_FactVenta_Precio CHECK(PrecioUnitario>0),
    CONSTRAINT CK_FactVenta_Costo CHECK(CostoUnitarioEstimado>=0),
    CONSTRAINT CK_FactVenta_Descuento CHECK(DescuentoImporte>=0 AND DescuentoImporte<Cantidad*PrecioUnitario)
);
-- Indices rowstore para el volumen inicial; evaluar columnstore al crecer y
-- medir planes reales, sin imponerlo prematuramente sobre columnas calculadas.
CREATE INDEX IX_FactVenta_TiempoSucursal ON dbo.FactVenta(TiempoKey,SucursalKey,TipoPedidoKey)
    INCLUDE(ProductoKey,Cantidad,VentaNeta,CostoTotalEstimado,MargenEstimado,PedidoIDOrigen);
CREATE INDEX IX_FactVenta_ProductoTiempo ON dbo.FactVenta(ProductoKey,TiempoKey)
    INCLUDE(Cantidad,VentaNeta,MargenEstimado);
CREATE INDEX IX_FactVenta_ClienteTiempo ON dbo.FactVenta(ClienteKey,TiempoKey)
    INCLUDE(PedidoIDOrigen,VentaNeta);
CREATE INDEX IX_FactVenta_SucursalTiempo ON dbo.FactVenta(SucursalKey,TiempoKey);
CREATE INDEX IX_FactVenta_EmpleadoTiempo ON dbo.FactVenta(EmpleadoKey,TiempoKey);
CREATE INDEX IX_FactVenta_TipoTiempo ON dbo.FactVenta(TipoPedidoKey,TiempoKey);
CREATE INDEX IX_FactVenta_Control ON dbo.FactVenta(IdControlCarga);

-- Dimensiones adicionales conformadas: sin FK entre dimensiones.
CREATE TABLE dbo.DimProveedor (
    ProveedorKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProveedor PRIMARY KEY,
    ProveedorIDOrigen int NOT NULL CONSTRAINT UQ_DimProveedor_Origen UNIQUE,
    RUC char(11) NOT NULL CONSTRAINT UQ_DimProveedor_RUC UNIQUE,
    RazonSocial nvarchar(150) NOT NULL,
    CONSTRAINT CK_DimProveedor_RUC CHECK(LEN(RUC)=11 AND RUC NOT LIKE '%[^0-9]%')
);
CREATE TABLE dbo.DimVehiculo (
    VehiculoKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimVehiculo PRIMARY KEY,
    VehiculoIDOrigen int NOT NULL CONSTRAINT UQ_DimVehiculo_Origen UNIQUE,
    Placa varchar(10) NOT NULL CONSTRAINT UQ_DimVehiculo_Placa UNIQUE,
    Descripcion nvarchar(80) NOT NULL
);
CREATE TABLE dbo.DimMetodoPago (
    MetodoPagoKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimMetodoPago PRIMARY KEY,
    MetodoPagoIDOrigen int NOT NULL CONSTRAINT UQ_DimMetodoPago_Origen UNIQUE,
    NombreMetodoPago nvarchar(40) NOT NULL
);

-- RECEPCION: una linea por (IngresoID, Linea), no una orden de compra.
CREATE TABLE dbo.FactRecepcionProducto (
    RecepcionKey bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactRecepcion PRIMARY KEY,
    TiempoKey int NOT NULL CONSTRAINT FK_Recepcion_Tiempo REFERENCES dbo.DimTiempo(TiempoKey),
    SucursalKey int NOT NULL CONSTRAINT FK_Recepcion_Sucursal REFERENCES dbo.DimSucursal(SucursalKey),
    EmpleadoKey int NOT NULL CONSTRAINT FK_Recepcion_Empleado REFERENCES dbo.DimEmpleado(EmpleadoKey),
    ProductoKey int NOT NULL CONSTRAINT FK_Recepcion_Producto REFERENCES dbo.DimProducto(ProductoKey),
    ProveedorKey int NOT NULL CONSTRAINT FK_Recepcion_Proveedor REFERENCES dbo.DimProveedor(ProveedorKey),
    IngresoIDOrigen int NOT NULL,
    LineaOrigen smallint NOT NULL,
    ReferenciaIngreso varchar(30) NOT NULL,
    Cantidad int NOT NULL,
    CostoUnitario decimal(12,2) NOT NULL,
    -- 22 digitos cubren el maximo de int * decimal(12,2) del origen.
    ImporteRecibido AS CONVERT(decimal(22,2),Cantidad*CostoUnitario) PERSISTED,
    IdControlCarga bigint NOT NULL CONSTRAINT FK_Recepcion_Control REFERENCES dbo.ETL_Control(IdControl),
    FechaCargaUTC datetime2(3) NOT NULL CONSTRAINT DF_Recepcion_Carga DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Recepcion_Origen UNIQUE(IngresoIDOrigen,LineaOrigen),
    CONSTRAINT CK_Recepcion_Linea CHECK(LineaOrigen>0),
    CONSTRAINT CK_Recepcion_Cantidad CHECK(Cantidad>0),
    CONSTRAINT CK_Recepcion_Costo CHECK(CostoUnitario>0)
);
CREATE INDEX IX_Recepcion_Tiempo ON dbo.FactRecepcionProducto(TiempoKey,SucursalKey)
    INCLUDE(Cantidad,ImporteRecibido);
CREATE INDEX IX_Recepcion_Producto ON dbo.FactRecepcionProducto(ProductoKey,TiempoKey);
CREATE INDEX IX_Recepcion_Proveedor ON dbo.FactRecepcionProducto(ProveedorKey,TiempoKey);
CREATE INDEX IX_Recepcion_Sucursal ON dbo.FactRecepcionProducto(SucursalKey,TiempoKey);
CREATE INDEX IX_Recepcion_Empleado ON dbo.FactRecepcionProducto(EmpleadoKey,TiempoKey);
CREATE INDEX IX_Recepcion_Control ON dbo.FactRecepcionProducto(IdControlCarga);

-- DELIVERY: snapshot acumulativo, una fila por PedidoID. Se actualiza al entregar.
-- TiempoEntregaKey NULL significa hito aun no ocurrido, no dimension desconocida.
-- Pendiente = salida registrada sin entrega (el origen exige FechaSalida).
-- CK_FactDelivery_Hito exige ambos valores de entrega NULL o ambos presentes.
-- DATEDIFF_BIG propaga NULL: transporte y total no se convierten en cero.
-- Completar mediante UPDATE de la misma fila; la clave de pedido sigue siendo unica.
-- CargoEnvio es cargo registrado, NO ingreso reconocido: no sumar pendientes como
-- ingresos. Entregada=1 acredita entrega fisica, no cierre financiero del pedido.
-- Conciliar con ventas exige ademas comprobar el cierre del pedido en el futuro ETL.
-- No se incorpora esa validacion de origen ni ninguna relacion entre hechos aqui.
CREATE TABLE dbo.FactDelivery (
    DeliveryKey bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactDelivery PRIMARY KEY,
    TiempoPedidoKey int NOT NULL CONSTRAINT FK_Delivery_TiempoPedido REFERENCES dbo.DimTiempo(TiempoKey),
    TiempoSalidaKey int NOT NULL CONSTRAINT FK_Delivery_TiempoSalida REFERENCES dbo.DimTiempo(TiempoKey),
    TiempoEntregaKey int NULL CONSTRAINT FK_Delivery_TiempoEntrega REFERENCES dbo.DimTiempo(TiempoKey),
    SucursalKey int NOT NULL CONSTRAINT FK_FactDelivery_Sucursal REFERENCES dbo.DimSucursal(SucursalKey),
    ClienteKey int NOT NULL CONSTRAINT FK_FactDelivery_Cliente REFERENCES dbo.DimCliente(ClienteKey),
    RepartidorKey int NOT NULL CONSTRAINT FK_FactDelivery_Repartidor REFERENCES dbo.DimEmpleado(EmpleadoKey),
    VehiculoKey int NOT NULL CONSTRAINT FK_FactDelivery_Vehiculo REFERENCES dbo.DimVehiculo(VehiculoKey),
    PedidoIDOrigen int NOT NULL CONSTRAINT UQ_FactDelivery_Origen UNIQUE,
    FechaHoraPedido datetime2(0) NOT NULL,
    FechaSalida datetime2(0) NOT NULL,
    FechaEntrega datetime2(0) NULL,
    CargoEnvio decimal(10,2) NOT NULL,
    Entregada AS CONVERT(bit,CASE WHEN FechaEntrega IS NULL THEN 0 ELSE 1 END) PERSISTED,
    MinutosPreparacion AS CONVERT(decimal(18,2),DATEDIFF_BIG(SECOND,FechaHoraPedido,FechaSalida)/60.0) PERSISTED,
    MinutosTransporte AS CONVERT(decimal(18,2),DATEDIFF_BIG(SECOND,FechaSalida,FechaEntrega)/60.0) PERSISTED,
    MinutosTotales AS CONVERT(decimal(18,2),DATEDIFF_BIG(SECOND,FechaHoraPedido,FechaEntrega)/60.0) PERSISTED,
    IdControlCarga bigint NOT NULL CONSTRAINT FK_FactDelivery_Control REFERENCES dbo.ETL_Control(IdControl),
    FechaCargaUTC datetime2(3) NOT NULL CONSTRAINT DF_FactDelivery_Carga DEFAULT SYSUTCDATETIME(),
    IdControlActualizacion bigint NULL CONSTRAINT FK_FactDelivery_ControlActualizacion REFERENCES dbo.ETL_Control(IdControl),
    FechaActualizacionUTC datetime2(3) NULL,
    CONSTRAINT CK_FactDelivery_Cargo CHECK(CargoEnvio>=0),
    CONSTRAINT CK_FactDelivery_Fechas CHECK(FechaSalida>=FechaHoraPedido AND (FechaEntrega IS NULL OR FechaEntrega>=FechaSalida)),
    CONSTRAINT CK_FactDelivery_Hito CHECK(
      (FechaEntrega IS NULL AND TiempoEntregaKey IS NULL)
      OR (FechaEntrega IS NOT NULL AND TiempoEntregaKey IS NOT NULL)),
    CONSTRAINT CK_FactDelivery_Actualizacion CHECK(
      (IdControlActualizacion IS NULL AND FechaActualizacionUTC IS NULL)
      OR (IdControlActualizacion IS NOT NULL AND FechaActualizacionUTC IS NOT NULL AND FechaActualizacionUTC>=FechaCargaUTC))
);
CREATE INDEX IX_FactDelivery_PedidoFecha ON dbo.FactDelivery(TiempoPedidoKey,SucursalKey);
CREATE INDEX IX_FactDelivery_SalidaFecha ON dbo.FactDelivery(TiempoSalidaKey,SucursalKey);
CREATE INDEX IX_FactDelivery_EntregaFecha ON dbo.FactDelivery(TiempoEntregaKey,SucursalKey)
    INCLUDE(CargoEnvio,MinutosTotales);
CREATE INDEX IX_FactDelivery_Sucursal ON dbo.FactDelivery(SucursalKey,TiempoSalidaKey);
CREATE INDEX IX_FactDelivery_Cliente ON dbo.FactDelivery(ClienteKey);
CREATE INDEX IX_FactDelivery_Repartidor ON dbo.FactDelivery(RepartidorKey,TiempoSalidaKey);
CREATE INDEX IX_FactDelivery_Vehiculo ON dbo.FactDelivery(VehiculoKey,TiempoSalidaKey);
CREATE INDEX IX_FactDelivery_Control ON dbo.FactDelivery(IdControlCarga);
CREATE INDEX IX_FactDelivery_ControlActualizacion ON dbo.FactDelivery(IdControlActualizacion);

-- PAGO: un cobro por PagoID. No es un pedido ni una linea de venta.
-- El origen no registra cajero de cobro ni distribucion del monto por producto.
CREATE TABLE dbo.FactPago (
    PagoKey bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactPago PRIMARY KEY,
    TiempoKey int NOT NULL CONSTRAINT FK_FactPago_Tiempo REFERENCES dbo.DimTiempo(TiempoKey),
    SucursalKey int NOT NULL CONSTRAINT FK_FactPago_Sucursal REFERENCES dbo.DimSucursal(SucursalKey),
    ClienteKey int NOT NULL CONSTRAINT FK_FactPago_Cliente REFERENCES dbo.DimCliente(ClienteKey),
    TipoPedidoKey int NOT NULL CONSTRAINT FK_FactPago_TipoPedido REFERENCES dbo.DimTipoPedido(TipoPedidoKey),
    MetodoPagoKey int NOT NULL CONSTRAINT FK_FactPago_Metodo REFERENCES dbo.DimMetodoPago(MetodoPagoKey),
    PagoIDOrigen int NOT NULL CONSTRAINT UQ_FactPago_Origen UNIQUE,
    ComprobanteIDOrigen int NOT NULL,
    PedidoIDOrigen int NOT NULL,
    SerieComprobante varchar(8) NOT NULL,
    NumeroComprobante int NOT NULL,
    FechaEmisionComprobante datetime2(0) NOT NULL,
    FechaHoraPago datetime2(0) NOT NULL,
    MontoCobrado decimal(14,2) NOT NULL,
    IdControlCarga bigint NOT NULL CONSTRAINT FK_FactPago_Control REFERENCES dbo.ETL_Control(IdControl),
    FechaCargaUTC datetime2(3) NOT NULL CONSTRAINT DF_FactPago_Carga DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_FactPago_Monto CHECK(MontoCobrado>0),
    CONSTRAINT CK_FactPago_Numero CHECK(NumeroComprobante>0),
    CONSTRAINT CK_FactPago_Fechas CHECK(FechaHoraPago>=FechaEmisionComprobante)
);
CREATE INDEX IX_FactPago_Tiempo ON dbo.FactPago(TiempoKey,SucursalKey) INCLUDE(MontoCobrado);
CREATE INDEX IX_FactPago_Sucursal ON dbo.FactPago(SucursalKey,TiempoKey);
CREATE INDEX IX_FactPago_Cliente ON dbo.FactPago(ClienteKey,TiempoKey);
CREATE INDEX IX_FactPago_Tipo ON dbo.FactPago(TipoPedidoKey,TiempoKey);
CREATE INDEX IX_FactPago_Metodo ON dbo.FactPago(MetodoPagoKey,TiempoKey) INCLUDE(MontoCobrado);
CREATE INDEX IX_FactPago_Pedido ON dbo.FactPago(PedidoIDOrigen);
CREATE INDEX IX_FactPago_Comprobante ON dbo.FactPago(ComprobanteIDOrigen);
CREATE INDEX IX_FactPago_Control ON dbo.FactPago(IdControlCarga);

-- 4. Procedimientos independientes de control (NO implementan el ETL).
-- SQL dinamico solo para definir los modulos dentro de la transaccion de DDL.
-- Los SP de control se llaman SIN transaccion externa para que el log sobreviva
-- al rollback de una futura carga. Antes de Fin_Error, revertir la carga fallida.
EXEC sys.sp_executesql N'
CREATE PROCEDURE dbo.SP_ETL_Inicio
    @Proceso nvarchar(128),
    @IdControl bigint OUTPUT,
    @Mensaje nvarchar(4000)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @IdControl=NULL;
    IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
        THROW 52100, ''El control ETL requiere autocommit y ninguna transaccion externa.'', 1;
    SET @Proceso=LTRIM(RTRIM(@Proceso));
    IF @Proceso IS NULL OR LEN(@Proceso)=0
        THROW 52101, ''Proceso es obligatorio.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Anterior datetime2(0);
        -- Bloqueo de rango por proceso; la unicidad filtrada protege ejecuciones simultaneas.
        SELECT TOP(1) @Anterior=UltimaFechaCarga
        FROM dbo.ETL_Control WITH(UPDLOCK,HOLDLOCK)
        WHERE Proceso=@Proceso AND Estado=''OK'' ORDER BY IdControl DESC;
        IF EXISTS(SELECT 1 FROM dbo.ETL_Control WHERE Proceso=@Proceso AND Estado=''EN_EJECUCION'')
            THROW 52102, ''Ya existe una ejecucion activa para este proceso.'', 1;
        INSERT dbo.ETL_Control(Proceso,UltimaFechaCarga,Mensaje)
        VALUES(@Proceso,@Anterior,@Mensaje);
        SET @IdControl=CONVERT(bigint,SCOPE_IDENTITY());
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SET @IdControl=NULL;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE PROCEDURE dbo.SP_ETL_Fin_OK
    @IdControl bigint,
    @UltimaFechaCarga datetime2(0)=NULL,
    @FilasProcesadas bigint=0,
    @Mensaje nvarchar(4000)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
        THROW 52100, ''El control ETL requiere autocommit y ninguna transaccion externa.'', 1;
    IF @FilasProcesadas IS NULL OR @FilasProcesadas<0
        THROW 52103, ''FilasProcesadas debe ser mayor o igual que cero.'', 1;
    -- Una sola actualizacion atomica. NULL conserva la marca de la ejecucion anterior.
    UPDATE dbo.ETL_Control
    SET Estado=''OK'',FechaFin=SYSUTCDATETIME(),
        UltimaFechaCarga=COALESCE(@UltimaFechaCarga,UltimaFechaCarga),
        FilasProcesadas=@FilasProcesadas,Mensaje=@Mensaje,NumeroError=NULL
    WHERE IdControl=@IdControl AND Estado=''EN_EJECUCION''
      AND (@UltimaFechaCarga IS NULL OR UltimaFechaCarga IS NULL OR @UltimaFechaCarga>=UltimaFechaCarga);
    IF @@ROWCOUNT<>1
        THROW 52104, ''Control inexistente, ya finalizado o marca de carga anterior a la vigente.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE PROCEDURE dbo.SP_ETL_Fin_Error
    @IdControl bigint,
    @Mensaje nvarchar(4000),
    @NumeroError int=NULL,
    @FilasProcesadas bigint=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
        THROW 52100, ''Revierta primero la carga fallida; registre el error fuera de su transaccion.'', 1;
    IF @Mensaje IS NULL OR LEN(LTRIM(RTRIM(@Mensaje)))=0
        THROW 52105, ''Debe indicar el mensaje del error.'', 1;
    IF @FilasProcesadas IS NULL OR @FilasProcesadas<0
        THROW 52103, ''FilasProcesadas debe ser mayor o igual que cero.'', 1;
    UPDATE dbo.ETL_Control
    SET Estado=''ERROR'',FechaFin=SYSUTCDATETIME(),Mensaje=@Mensaje,
        NumeroError=@NumeroError,FilasProcesadas=@FilasProcesadas
    WHERE IdControl=@IdControl AND Estado=''EN_EJECUCION'';
    IF @@ROWCOUNT<>1
        THROW 52106, ''El control no existe o ya finalizo.'', 1;
END;';

-- 5. Generador del calendario: solo definicion, NO se invoca en este archivo.
-- Rango inclusivo, sin filas duplicadas ni dependencia de idioma o DATEFIRST.
-- Se limita cada llamada a 100000 dias; admite ampliar el calendario por rangos.
EXEC sys.sp_executesql N'
CREATE PROCEDURE dbo.SP_Poblar_DimTiempo
    @FechaInicio date,
    @FechaFin date
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
        THROW 52200, ''Ejecute el calendario sin transaccion externa y en autocommit.'', 1;
    IF @FechaInicio IS NULL OR @FechaFin IS NULL OR @FechaFin<@FechaInicio
        THROW 52201, ''Indique un rango de fechas valido e inclusivo.'', 1;
    DECLARE @Dias int=DATEDIFF(DAY,@FechaInicio,@FechaFin)+1;
    IF @Dias>100000
        THROW 52202, ''Use rangos de hasta 100000 dias por llamada.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Bloqueo int;
        EXEC @Bloqueo=sys.sp_getapplock @Resource=N''DM_Cafeteria.DimTiempo'',
            @LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=10000;
        IF @Bloqueo<0
            THROW 52203, ''No se pudo obtener el bloqueo del calendario.'', 1;
        ;WITH dig(n) AS (
            SELECT n FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9))v(n)
        ), numeros AS (
            SELECT TOP(@Dias) CONVERT(int,ROW_NUMBER() OVER(ORDER BY (SELECT NULL))-1) AS n
            FROM dig a CROSS JOIN dig b CROSS JOIN dig c CROSS JOIN dig d CROSS JOIN dig e
        )
        -- Se inserta solo Fecha: SQL Server calcula automaticamente las columnas
        -- PERSISTED, incluidos NumeroSemana, AnioSemanaISO, AnioTrimestre,
        -- AnioMes, AnioMesNombre y MesCorto. No asignar columnas calculadas.
        INSERT dbo.DimTiempo(Fecha)
        SELECT DATEADD(DAY,n,@FechaInicio) FROM numeros
        WHERE NOT EXISTS(SELECT 1 FROM dbo.DimTiempo WITH(UPDLOCK,HOLDLOCK)
            WHERE Fecha=DATEADD(DAY,n,@FechaInicio));
        DECLARE @Insertadas int=@@ROWCOUNT;
        COMMIT TRANSACTION;
        SELECT @Insertadas AS FechasInsertadas;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

-- 6. Comprobacion final: no se ha invocado ningun procedimiento ni cargado filas.
IF EXISTS(SELECT 1 FROM dbo.DimTiempo) OR EXISTS(SELECT 1 FROM dbo.DimProducto)
 OR EXISTS(SELECT 1 FROM dbo.DimCliente) OR EXISTS(SELECT 1 FROM dbo.DimSucursal)
 OR EXISTS(SELECT 1 FROM dbo.DimEmpleado) OR EXISTS(SELECT 1 FROM dbo.DimTipoPedido)
 OR EXISTS(SELECT 1 FROM dbo.FactVenta) OR EXISTS(SELECT 1 FROM dbo.ETL_Control)
 OR EXISTS(SELECT 1 FROM dbo.DimProveedor) OR EXISTS(SELECT 1 FROM dbo.DimVehiculo)
 OR EXISTS(SELECT 1 FROM dbo.DimMetodoPago) OR EXISTS(SELECT 1 FROM dbo.FactRecepcionProducto)
 OR EXISTS(SELECT 1 FROM dbo.FactDelivery) OR EXISTS(SELECT 1 FROM dbo.FactPago)
    THROW 52300, 'El Data Mart debe quedar completamente vacio.', 1;
COMMIT TRANSACTION;
DROP TABLE #DM_Cafeteria_Instalacion;
PRINT N'DM_Cafeteria creada: 9 dimensiones, 4 hechos y ETL_Control. Todas las tablas vacias.';
PRINT N'Los 4 procedimientos estan definidos; no se ejecuto ninguno ni se cargo el calendario.';
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
