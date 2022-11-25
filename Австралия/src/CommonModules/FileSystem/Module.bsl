///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

#Region TemporaryFiles

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to manage temporary files.

// Creates a temporary directory. If a temporary directory is not required anymore, deleted it with 
// the FileSystem.DeleteTemporaryDirectory procedure.
//
// Parameters:
//   Extension - String - the temporary directory extension that contains the directory designation 
//                         and its subsystem.
//                         It is recommended that you use only Latin characters in this parameter.
//
// Returns:
//   String - full path to the directory, including path separators.
//
Function CreateTemporaryDirectory(Val Extension = "") Export
	
	PathToDirectory = CommonClientServer.AddLastPathSeparator(GetTempFileName(Extension));
	CreateDirectory(PathToDirectory);
	Return PathToDirectory;
	
EndFunction

// Deletes the temporary directory and its content if possible.
// If a temporary directory cannot be deleted (for example, if it is busy), the procedure is 
// completed and the warning is added to the event log.
//
// This procedure is for using with the FileSysyem.CreateTemporaryDirectory procedure after a 
// temporary directory is not required anymore.
//
// Parameters:
//   Path - String - a full path to a temporary directory.
//
Procedure DeleteTemporaryDirectory(Val Path) Export
	
	If IsTempFileName(Path) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Неверное значение параметра Path в FileSystem.DeleteTemporaryDirectory:
				       |Каталог не является временным ""%1""'; 
				       |en = 'Invalid value of the Path parameter in FileSystem.DeleteTemporaryDirectory:
				       |The directory is not temporary: %1'; 
				       |pl = 'Nieprawidłowa wartość parametru Ścieżk w FileSystem.DeleteTemporaryDirectory:
				       |Katalog nie jest tymczasowy: %1';
				       |es_ES = 'Valor inválido del parámetro de Ruta en FileSystem.DeleteTemporaryDirectory:
				       |El directorio no es temporal: %1';
				       |es_CO = 'Valor inválido del parámetro de Ruta en FileSystem.DeleteTemporaryDirectory:
				       |El directorio no es temporal: %1';
				       |tr = 'FileSystem.DeleteTemporaryDirectory içinde Path parametresinin değeri geçersiz:
				       |Dizin geçici değil: %1';
				       |it = 'Valore non valido del parametro di Percorso in FileSystem.DeleteTemporaryDirectory:
				       | la Directory non è temporanea: %1';
				       |de = 'Ungültiger Wert des Pfad-Parameters in FileSystem.DeleteTemporaryDirectory:
				       |Das Verzeichnis ist nicht temporär: %1'"), 
			Path);
	EndIf;
	
	DeleteTempFiles(Path);
	
EndProcedure

// Deletes a temporary file.
// If a temporary file cannot be deleted (for example, if it is busy), the procedure is completed 
// and the warning is added to the event log.
//
// This procedure is for using with the GetTempFileName method after a temporary file is not 
// required anymore.
//
// Parameters:
//   Path - String - a full path to a temporary file.
//
Procedure DeleteTempFile(Val Path) Export
	
	If IsTempFileName(Path) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Неверное значение параметра Path в FileSystem.DeleteTemporaryFile:
				       |Файл не является временным ""%1""'; 
				       |en = 'Incorrect value of the Path parameter in FileSystem.DeleteTemporaryFile:
				       |The file is not temporary: %1'; 
				       |pl = 'Niepoprawna wartość w parametrze Ścieżka w FileSystem.DeleteTemporaryFile:
				       |Plik nie jest tymczasowy: %1';
				       |es_ES = 'Valor incorrecto del parámetro de Ruta en FileSystem.DeleteTemporaryFile:
				       |El archivo no es temporal: %1';
				       |es_CO = 'Valor incorrecto del parámetro de Ruta en FileSystem.DeleteTemporaryFile:
				       |El archivo no es temporal: %1';
				       |tr = 'FileSystem.DeleteTemporaryFile içinde Path parametresinin değeri yanlış:
				       |Dosya geçici değil: %1';
				       |it = 'Valore errato del parametro di Percorso in FileSystem.DeleteTemporaryFile:
				       | Il file non è temporaneo: %1';
				       |de = 'Falscher Wert des Pfad-Parameters in FileSystem.DeleteTemporaryFile:
				       |Die Datei ist nicht temporär: %1'"), 
			Path);
	EndIf;
	
	DeleteTempFiles(Path);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

Procedure DeleteTempFiles(Val Path)
	
	Try
		DeleteFiles(Path);
	Except
		WriteLogEvent(
			NStr("ru = 'Стандартные подсистемы'; en = 'Standard subsystems'; pl = 'Standardowe podsystemy';es_ES = 'Subsistemas estándar';es_CO = 'Subsistemas estándar';tr = 'Standart alt sistemler';it = 'Sottosistemi standard';de = 'Standard-Subsysteme'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось удалить временный файл ""%1"" по причине:
					|%2'; 
					|en = 'Cannot delete temporary file %1. Reason:
					|%2'; 
					|pl = 'Nie można usunąć czasowego pliku %1. Przyczyna:
					|%2';
					|es_ES = 'No se ha podido eliminar el archivo temporal %1. A causa de:
					|%2';
					|es_CO = 'No se ha podido eliminar el archivo temporal %1. A causa de:
					|%2';
					|tr = '%1 geçici dosyası silinemiyor. Nedeni:
					|%2';
					|it = 'Impossibile eliminare il file temporaneo %1. Causa: 
					|%2';
					|de = 'Kann temporäre Datei %1 nicht löschen. Grund:
					|%2'"),
				Path,
				DetailErrorDescription(ErrorInfo())));
	EndTry;
	
EndProcedure

Function IsTempFileName(Path)
	
	// The Path is expected to have been obtained with the GetTempFileName() method.
	// Before the check, slashes are converted into backslashes.
	Return Not StrStartsWith(StrReplace(Path, "/", "\"), StrReplace(TempFilesDir(), "/", "\"));
	
EndFunction

#EndRegion