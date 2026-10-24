/* =====================================================================
   validacion.sql  -  Proyecto BI Cafetería (Grupo 02)
   Consultas de conciliación y coherencia (Anexo D del informe).
   Ejecutar en SSMS, conectado a localhost, después de cada carga.
   ===================================================================== */

/* 1. FUENTE: filas e importes que deben llegar al data mart */
USE Cafeteria;
GO
SELECT COUNT(*) AS LineasVenta,
       SUM(d.Cantidad*d.PrecioUnitario-d.Descuento) AS VentaNeta
FROM dbo.PedidoVenta p
JOIN dbo.DetallePedidoVenta d ON d.PedidoID = p.PedidoID
WHERE p.EstadoPedidoID = 2;                       -- solo pedidos completados

SELECT COUNT(*) AS Pagos, SUM(Monto) AS MontoCobrado FROM dbo.Pago;
SELECT COUNT(*) AS Entregas FROM dbo.Delivery;
SELECT COUNT(*) AS LineasIngreso, SUM(Cantidad*CostoUnitario) AS Importe
FROM dbo.DetalleIngresoProducto;
GO

/* 2. DATA MART: última carga y conteos */
USE DM_Cafeteria;
GO
SELECT TOP 3 IdControl, Estado, FilasProcesadas, FechaInicio, FechaFin
FROM dbo.ETL_Control ORDER BY IdControl DESC;

SELECT (SELECT COUNT(*) FROM dbo.FactVenta)             AS FactVenta,
       (SELECT COUNT(*) FROM dbo.FactRecepcionProducto) AS FactRecepcion,
       (SELECT COUNT(*) FROM dbo.FactDelivery)          AS FactDelivery,
       (SELECT COUNT(*) FROM dbo.FactPago)              AS FactPago;

/* 3. INDICADORES (comparar con el cubo y con Power BI) */
SELECT SUM(VentaNeta)                       AS VentaNeta,
       COUNT(DISTINCT PedidoIDOrigen)       AS Pedidos,
       SUM(VentaNeta)/COUNT(DISTINCT PedidoIDOrigen) AS TicketPromedio,
       SUM(MargenEstimado)/SUM(VentaNeta)   AS PctMargen
FROM dbo.FactVenta;

SELECT SUM(MontoCobrado) AS MontoCobrado FROM dbo.FactPago;

/* 4. COHERENCIA DE NEGOCIO (EXP-05): compras / costo de ventas entre 1,00 y 1,15 */
SELECT r.Importe / v.Costo AS ComprasSobreCostoVentas,
       r.Importe / v.Venta AS ComprasSobreVenta
FROM (SELECT SUM(ImporteRecibido) AS Importe
      FROM dbo.FactRecepcionProducto) r
CROSS JOIN (SELECT SUM(CostoTotalEstimado) AS Costo, SUM(VentaNeta) AS Venta
            FROM dbo.FactVenta) v;
GO
