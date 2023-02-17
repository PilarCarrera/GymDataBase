use gestionGimnasio_BD_Grupo12_2021;
go

-------------------------------------------------FUNCIONES-------------------------------------------------

--Retorna num actividades a las que esta apuntado ahora mismo el socio en la matricula vigente

create or alter function numActividadesApuntado (@idMatricula int)

returns int
as begin

	declare @numActividades int
	
	set @numActividades =
		(select count(*) from MatriculaActividades ma inner join
			matricula m on ma.idMatricula = m.idMatricula
			where m.idMatricula = @idMatricula
			and ma.vigente = 1
		)	

	return @numActividades
end;
go


--Retorna todos los socios que estan apuntados a una actividad

create or alter function socioApuntadosActividad (@idActividad int)
returns table
as

return 

	select numSocio from Matricula as m
	inner join MatriculaActividades MA on m.idMatricula = MA.idMatricula
	where MA.vigente = 1 and MA.idActividades = @idActividad
	
go

--Una función que retorna todas las matrículas que ha tenido un determinado socio (vigentes y no vigentes)

create or alter function matriculaSocioFuncion (@numSocio int)
returns table
as

return 

	select m.* from Matricula as m
	inner join MatriculaActividades MA on m.idMatricula = MA.idMatricula
	where  @numSocio = m.numSocio
	
go

--Una función que devuelve todos los usuarios golden del gimnasio

create or alter function sociosGold()
returns table
as
	return (select * from Socio s
			where s.golden = 1)
go

--Funcion que devuelve todos los usuarios que tienen un tipo de descuento determinado
create or alter function descuentoUsuario(@idDescuento int)
returns table
as

	return  select s.* from Socio s 
			inner join matricula m on m.numSocio = s.NumSocio
			where m.Descuento = @idDescuento

go

--Retorna una actividad concreta
create or alter function retornaActividad(@idActividad int)
returns table
as

return select a.* from Actividad a where a.idActividad = @idActividad

go

--Devuelve todos las actividades a las que esta dando clase ahora el profesor
create or alter function profesorActividadFuncion(@idProfesor int)
returns table

as
	return (select p.idProfesor, p.nombre, p.numTelefono, PA.idActividad, PA.NumProfesor
	from Profesor p inner join ProfesorActividad PA on p.idProfesor = PA.NumProfesor
	where @idProfesor = p.idProfesor and PA.profesorActivo = 1
	group by p.idProfesor, p.nombre, p.numTelefono, PA.idActividad, PA.NumProfesor)

go

--Imprime todas las actividades a las que esta apuntado un alumno del gimnasio
create or alter function alumnoActividadFuncion(@idAlumno int)

returns table
as

	return 
	(select a.*
	from MatriculaActividades ma inner join Actividad a
										on a.idActividad = ma.idActividades
								 inner join Matricula m
										on ma.idMatricula = m.idMatricula
	where @idAlumno = m.numSocio)

go



--Imprime todas las actividades que hay en cada franja horaria
create or alter function actividadFranjaHoraria(@idFranjaHoraria int)
returns table
as

	return 
	select a.idActividad, a.NombreActividad 
	from actividad a inner join franjaHoraria fH on a.FranjaHoraria = fH.idFranjaHoraria
	where fh.idFranjaHoraria = @idFranjaHoraria
	group by a.idActividad, a.NombreActividad

go

--Imprime todos los descuentos con los usuaios que lo están utilizando actualmente
create or alter function descuentoSocioFuncion(@idDescuento int)
returns table
as

	return
	select m.Descuento, m.numSocio, d.Nombre
	from Matricula m inner join descuento d on d.idDescuento = m.Descuento
	where d.idDescuento = @idDescuento
	group by m.Descuento, m.numSocio, d.Nombre

go

---------------------------------------------VISTAS------------------------------------------------

--Imprime todos los socios que ha habido en el gimnasio
create view socioDatos as
select * from Socio;
go

--Imprime todos los datos de los profesores del gimnasio
create view profesoresDatos as
	select * from Profesor;
go

--Imprime todas las actividades que ha habido en el gimnasio
create view muestraActividades
as
select * from Actividad;
go


-------------------------------PROCEDIMIENTOS---------------------------------------


CREATE or alter PROCEDURE usp_showerrorinfo
AS
    SELECT  ERROR_NUMBER() AS [Numero de Error],
            ERROR_STATE() AS [Estado del Error],
            ERROR_SEVERITY() AS [Severidad del Error],
            ERROR_LINE() AS [Linea],
            ISNULL(ERROR_PROCEDURE(), 'No esta en un proc') AS [Procedimiento],
            ERROR_MESSAGE() AS [Mensaje]
GO

--Procedimiento para añadir una nueva actividad

create or alter procedure anyadirNuevaActividad @idActividad int, @NombreActividad char(20), @Descripcion varchar(100), @idSala int, @franjaHoraria int,
@AforoActividad int, @FechaInicio date, @FechaFin date, @PrecioActividad smallmoney, @IVA int, @enCurso bit
as
begin try

	insert into Actividad(idActividad, NombreActividad, Descripcion, Sala, FranjaHoraria, AforoActividad, FechaInicio, FechaFin, PrecioActividad, IVA, enCurso)
	values(@idActividad, @NombreActividad, @Descripcion, @idSala, @franjaHoraria, @AforoActividad, @FechaInicio, @FechaFin, @PrecioActividad, @IVA, @enCurso)

end try
begin catch

	rollback transaction
	raiserror('Ha habido un error al añadir la nueva actividad',16,1)

end catch;
go

--Actualizar aforo de la sala

create or alter procedure actualizaAforoActividad @idActividad int, @nuevoAforo int
as
begin try

	update Actividad set AforoActividad =  @nuevoAforo
	where idActividad = @idActividad

end try
begin catch

	rollback transaction
	raiserror('Ha habido un error al actualizar el aforo de la sala',16,1)

end catch;
go

--Trigger para controlar la no eliminacion de los profesores (se les pasa de activo a no activo)
create or alter trigger tg_noEliminacion_Profesor on ProfesorActividad instead of delete
as
begin
    update ProfesorActividad
    set profesorActivo = 0
    where idActividad in (select idActividad from deleted)
end;
go

--Actualizar correo profesor
create or alter procedure actualiza_correo_profesor @idProfesor int, @nuevoCorreo varchar(50)
as
    begin try
            begin transaction

                update Profesor
                set correo = @nuevoCorreo
                where idProfesor = @idProfesor

            commit transaction
    end try

    begin catch
        rollback transaction
        exec usp_showerrorinfo
    end catch;
	go

-- Añadir un nuevo profesor
create or alter procedure pd_anhade_profesor @idProfesor int, @nombre char, @apellido1 char,
@apellido2 char, @nif char, @correo varchar, @numTelefono char
as
begin try
    begin transaction

        insert into profesor(idProfesor, nombre, apellido1, apellido2, nif, correo,
		numTelefono)
        values(@idProfesor, @nombre, @apellido1, @apellido2, @nif, @correo, @numTelefono)

    commit transaction
end try

begin catch
rollback transaction
        exec usp_showerrorinfo
end catch;
go

--Disparador que evita el borrado de un socio en una actividad (se cambia de en curso a no en curso)
create or alter trigger tg_noEliminacion_Actividad on Actividad instead of delete
as
begin
    update Actividad
    set enCurso = 0
    where idActividad in (select idActividad from deleted)
end;
go



-- Actualizar correo del cliente
create or alter procedure pd_actualiza_correo @idSocio int, @correo varchar(50) as
begin try
    begin transaction

        if (select count(*) from Socio where numSocio = @idSocio) = 0
        begin
            raiserror('No existe el socio indicado', 16, 1)
        end

        update socio set correo = @correo where NumSocio = @idSocio

    commit transaction
end try

begin catch
rollback transaction
        exec usp_showerrorinfo
end catch;
go


--Añadir socios al gimnasio
create or alter procedure añadeSocio @NumSocio int, @nombre char(20), @apellido1 char(20), @apellido2 char(20), @nif char(9),
@correo varchar(50), @numTelefono char(9), @golden bit, @FechaNacimiento date

as
begin try
		begin transaction

				insert into Socio ( NumSocio, nombre, apellido1, apellido2, nif, correo, numTelefono, golden, FechaNacimiento) 
				values (@NumSocio, @nombre, @apellido1, @apellido2, @nif, @correo, @numTelefono, @golden, @FechaNacimiento)

		commit transaction
end try
begin catch
		rollback transaction
		exec usp_showerrorinfo
		return
end catch;
go


--Crear matricula al socio

create or alter procedure anhadirSocioAMatricula @NumSocio int, @idMAtricula int,
@Descuento int, @fechaMatricula date, @fechaCancelacion date
as
begin try
		begin transaction

				insert into Matricula (idMAtricula, Descuento, NumSocio, fechaMatricula, fechaCancelacion)
				values (@idMAtricula, @Descuento, @NumSocio, @fechaMatricula, @fechaCancelacion)

		commit transaction
end try
begin catch
		rollback transaction
		exec usp_showerrorinfo
		return
end catch;
go

--Si ese aula esta ocupada o no en esa franja horaria

create or alter procedure aulaOcupadaFranjaHoraria @actividad int, @sala int, @franja int as begin
begin try
		begin transaction

				declare @horarioInicio time
				declare @horarioFin time

				select @horarioInicio = (select HoraInicio from franjaHoraria
				where @franja = idFranjaHoraria) 

				select @horarioFin = (select HoraFin from franjaHoraria
				where @franja = idFranjaHoraria) 

				if ((select count(*) from actividad a
				inner join franjaHoraria FH on FH.idFranjaHoraria = a.FranjaHoraria
				where a.franjaHoraria = @franja and a.sala = @sala 
				and ((@horarioInicio <= HoraInicio and @horarioFin >= HoraInicio)
                       or (@horarioInicio >= HoraInicio and @horarioFin <= HoraFin)
                       or (@horarioInicio <= HoraFin and @horarioFin >= HoraFin)))) > 0
				begin
						raiserror('Error al actualizar el aula', 16, 1)
				end
				update actividad set sala = @sala where actividad.idActividad = @actividad
		commit transaction
end try
begin catch
		rollback transaction
		exec usp_showerrorinfo
		return
end catch;
end
