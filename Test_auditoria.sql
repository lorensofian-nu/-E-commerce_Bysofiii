use ecommerce_bysofii;

UPDATE clientes
SET email = 'nuevo_email@example.com' WHERE id_cliente = 1;

select * from Auditoria_Clientes;

update clientes
set direccion_envio = 'Calle Nueva 123' where id_cliente = 1;

update clientes
set nombre = 'Juan Perez' where id_cliente = 1;
