------------------------------------------------------------------
---- Trabajo grupal gestión de gimnasio:
---- Bases de datos ----------------------------------------------
---- Ingeniería Informática, Universidad de Cantabria ------------
---- 2020/2021 ---------------------------------------------------
------------------------------------------------------------------

-- Eliminar base de datos si existe (recreación completa)

USE master;  --base de datos del sistema
go

IF EXISTS(select * from sys.databases where name='gestionGimnasio_BD_Grupo12_2021')
  DROP DATABASE gestionGimnasio_BD_Grupo12_2021;	
go

-- Crea la base de datos
create database gestionGimnasio_BD_Grupo12_2021;
go

-- Usar la base de datos creada
use gestionGimnasio_BD_Grupo12_2021;				
go

--Franja horaria de las actividades
create table franjaHoraria (

	idFranjaHoraria int primary key not null,
	HoraInicio time not null,
	HoraFin time not null,

	constraint ck_horaInicioFin check(HoraInicio < HoraFin)

);

--Datos de la sala donde se van a realizar las actividades
create table Sala (	

	idSala int primary key not null,
	NumeroSala int not null,
	AforoSala int not null

);

--Actividades que se han realizado en el gimnasio
create table Actividad (

	idActividad int primary key not null,
	NombreActividad char(20) not null,
	Descripcion varchar(100) not null,
	Sala int not null foreign key references sala(idSala) ,
	FranjaHoraria int null foreign key references franjaHoraria(idFranjaHoraria),
	AforoActividad int not null, --UTILIZAMOS UN TRIGGER -- constraint ck_AforoSAlaActividad check(AforoSala > Actividad(AforoActividad)),
	FechaInicio date not null default getdate(),
	FechaFin date null,
	PrecioActividad smallmoney not null,
	IVA smallmoney not null, 
	--procedimiento actividad en curso o no
	enCurso bit not null default 0, 


	constraint ck_fechaInicioFin check(FechaInicio < FechaFin)

);

alter table Actividad alter Column IVA smallmoney




--Descuentos disponibles
create table Descuento (	

	idDescuento int primary key not null,
	CantidadDescuento smallmoney not null,
	Nombre char(10) not null,
	Descripcion varchar(100) not null

);

--Profesores del gimnasio
create table Profesor (	
 
	idProfesor int primary key not null,
	nombre char(20) not null,
	apellido1 char(20) not null,
	apellido2 char(20) null,
	nif char(9) not null check (nif like ('[KLMXYZ0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][A-Z]')) unique,
	correo varchar(50) not null unique check (correo like ('%_@_%_.__%')),
	numTelefono char(9) not null check (numTelefono like ('[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')),

);

--Tabla que relaciona a los profesores con la acctividad que imparten
create table ProfesorActividad (

	idActividad int not null,
	NumProfesor int not null,
	profesorActivo bit not null default 1, --procedimiento update 

	constraint PK_profesorActividad primary key (idActividad, NumProfesor),
	constraint FK_idActividad_ProfesorActv foreign key (idActividad) references Actividad(idActividad) ON UPDATE CASCADE,
	constraint FK_idProfesor_ProfesorActv foreign key (NumProfesor) references Profesor(idProfesor) ON UPDATE CASCADE,

);

--Socios del gimnasio
create table Socio (	
 
	NumSocio int primary key not null,
	nombre char(20) not null,
	apellido1 char(20) not null,
	apellido2 char(20) null,
	nif char(9) not null check (nif like ('[KLMXYZ0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][A-Z]')) unique,
	correo varchar(50) not null unique check (correo like ('%_@_%_.__%')),
	numTelefono char(9) not null check (numTelefono like ('[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')),
	golden bit not null default 0,
	FechaNacimiento date not null

);
go

--Calcula el valor total de la matricula de un socio, teniendo en cuenta su descuento, el IVA asi como si tiene la membresia golden
create or alter function calculaPrecioMatricula(@idMatricula int) 
returns smallmoney
as begin

	declare @descuentoMat smallmoney
	declare @precioTotalAct smallmoney
	declare @precioMat smallmoney
	declare @precioTotalActIVA smallmoney

	select @descuentoMat = ((select d.CantidadDescuento
	from Descuento d inner join matricula m on m.Descuento = d.idDescuento 
	where m.idMatricula = @idMatricula))

	if (@descuentoMat is null)
		set @descuentoMat = 0

	select @precioTotalAct = (select sum(a.PrecioActividad)
	from Actividad a inner join MatriculaActividades ma
	on ma.idActividades = a.idActividad
	where ma.idMatricula = @idMatricula) 

	if @precioTotalAct is null
		set @precioTotalAct = 0

	select @precioTotalActIVA = @precioTotalAct + (@precioTotalAct *
	(select a.IVA from Actividad a 
	inner join MatriculaActividades ma
	on ma.idActividades = a.idActividad
	where ma.idMatricula = @idMatricula)) 

	if @precioTotalActIVA is null
		set @precioTotalActIVA = 0

	set @precioMat = @precioTotalActIVA - @descuentoMat

	return @precioMat
end;
go

--Matricula que relaciona al usuario con la actividad y el descuento determinado
create table Matricula (

	idMatricula int primary key not null,
	Descuento int not null,
	--Precio smallmoney not null, --calculado con funcion
	numSocio int  not null,
	fechaMatricula date  not null,
	fechaCancelacion date null,
	precio as dbo.calculaPrecioMatricula(idMatricula),

	constraint fk_idDescuento_Matricula foreign key (Descuento) references Descuento (idDescuento),
	constraint fk_idSocio_Matricula foreign key (NumSocio) references Socio (NumSocio) ON UPDATE CASCADE 

);

--Tabla que relaciona la actividad a la que esta apuntado un cliente en su matricula
create table MatriculaActividades (

	idActividades int not null,
	idMatricula int not null,
	vigente bit not null default 1,

	constraint PK_MatriculaActividades primary key (idActividades, idMatricula),
	constraint FK_idActividad_MatriculaActv foreign key (idActividades) references Actividad(idActividad) ON UPDATE CASCADE,
	constraint FK_idMatricula_MatriculaActv foreign key (idMatricula) references Matricula(idMatricula) ON UPDATE CASCADE 

)

--Inserts para añadir datos a la bd

--franja horaria

insert into franjaHoraria(idFranjaHoraria, HoraInicio,HoraFin)
values(0, '16:00','18:00')


insert into franjaHoraria(idFranjaHoraria, HoraInicio,HoraFin)
values(1, '18:00','21:00')

insert into franjaHoraria(idFranjaHoraria, HoraInicio,HoraFin)
values(2, '10:30','11:30')

--sala

insert into Sala(idSala, NumeroSala, AforoSala)
values(0, 0, 10)

insert into Sala(idSala, NumeroSala, AforoSala)
values(1, 1, 5)

insert into Sala(idSala, NumeroSala, AforoSala)
values(2, 2, 2)

--Insertamos Actividad
insert into Actividad(idActividad, NombreActividad, Descripcion, Sala, FranjaHoraria, AforoActividad, FechaFin, PrecioActividad, IVA, enCurso)
values(0, 'Natacion', 'Actividad de Natación', 0, 0, 2, '31-05-2021', 20, 0.05, 1)

update Actividad set IVA = 0.05 where idActividad = 0

insert into Actividad(idActividad, NombreActividad, Descripcion, Sala, FranjaHoraria, AforoActividad, FechaFin, PrecioActividad, IVA, enCurso)
values(1, 'Correr', 'Actividad de Correr', 1,1, 10, '31-05-2021', 10, 0.02, 1)

update Actividad set IVA = 0.02 where idActividad = 1

insert into Actividad(idActividad, NombreActividad, Descripcion, Sala, FranjaHoraria, AforoActividad, FechaFin, PrecioActividad, IVA, enCurso)
values(2, 'Tiro con Arco', 'Actividad de Tiro con Arco', 2, 2, 5, '31-05-2021', 30, 0.05, 0)


update Actividad set IVA = 0.05 where idActividad = 2

--Descuento

insert into Descuento(idDescuento, CantidadDescuento, Nombre, Descripcion)
values(0, 10, 'Senior', 'Cupon para personas mayores de 60 años')

insert into Descuento(idDescuento, CantidadDescuento, Nombre, Descripcion)
values(1, 20, 'Joven', 'Cupon para personas menores de 18 años')

insert into Descuento(idDescuento, CantidadDescuento, Nombre, Descripcion)
values(2, 30, 'golden', 'Cupon para personas con matricula golden apuntadas a mas de 5 actividades')

--Profesor

insert into profesor(idProfesor, nombre, apellido1, apellido2, nif, correo,numTelefono)
values(0, 'Marta', 'Sanchez', 'Rodriguez', '72234562X', 'soyProfesional@kmail.com', '650342080')

insert into profesor(idProfesor, nombre, apellido1, apellido2, nif, correo,numTelefono)
values(1, 'Elena', 'Villa', 'Smith', '72234563X', 'correo2@kmail.com', '650342085')

insert into profesor(idProfesor, nombre, apellido1, apellido2, nif, correo,numTelefono)
values(2, 'Eloy', 'Alcantara', 'De La Osa', '72234569X', 'meGustaFornite@kmail.com', '650342090')

--Profesor actividad

insert into ProfesorActividad(idActividad, NumProfesor, profesorActivo)
values(0,0,1)

insert into ProfesorActividad(idActividad, NumProfesor, profesorActivo)
values(1,1,1)

insert into ProfesorActividad(idActividad, NumProfesor, profesorActivo)
values(2,2,0)


--Socios
insert into Socio (NumSocio, nombre, apellido1, apellido2, nif, correo, numTelefono, golden, FechaNacimiento)
values(0, 'Pilar', 'Zamanillo', 'Mediavilla', '00000000X', 'juanjoMola@kmail.com', '650342085', '0', '05-06-2001')

insert into Socio (NumSocio, nombre, apellido1, apellido2, nif, correo, numTelefono, golden, FechaNacimiento)
values(1, 'Irene', 'Diaz', 'Monterde', '11111111X', 'elTrollDelForo@kmail.com', '650342086', '1', '06-06-2001')

insert into Socio (NumSocio, nombre, apellido1, apellido2, nif, correo, numTelefono, golden, FechaNacimiento)
values(2, 'Juanjo', 'Carrera', 'Zubizarreta', '22222222X', 'clubDeFansDeSergio@kmail.com', '650342187', '1', '07-06-2001')

insert into Socio (NumSocio, nombre, apellido1, apellido2, nif, correo, numTelefono, golden, FechaNacimiento)
values(3, 'Pepa', 'Carrera', 'Zubizarreta', '33333333X', 'andaYa@kmail.com', '650342194', '1', '07-06-2001')


--Matricula

insert into Matricula(idMatricula,Descuento,numSocio, fechaMatricula)
values(0,0,0,'22-05-2021')

insert into Matricula(idMatricula,Descuento,numSocio, fechaMatricula)
values(1,1,1,'22-05-2021')


insert into Matricula(idMatricula,Descuento,numSocio, fechaMatricula)
values(2,2,2,'22-05-2021')


insert into Matricula(idMatricula,Descuento,numSocio, fechaMatricula)
values(5,0,3,'22-05-2021')


--MatriculaActividades

insert into MatriculaActividades(idActividades,idMatricula,vigente)
values(0,0,1)

insert into MatriculaActividades(idActividades,idMatricula,vigente)
values(0,1,1)

insert into MatriculaActividades(idActividades,idMatricula,vigente)
values(1,1,1)


update Actividad set enCurso = 1 where idActividad = 1