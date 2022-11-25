#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PartSize = Parameters.PartSize;
	RepeatCount = Parameters.RepeatCount;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Result = New Structure;
	Result.Insert("PartSize", PartSize);
	Result.Insert("RepeatCount", RepeatCount);
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	Notify(NStr("en = 'Advanced Setting'; ru = 'Расширенная настройка';pl = 'Ustawienia zaawansowane';es_ES = 'Configuración avanzada';es_CO = 'Configuración avanzada';tr = 'Gelişmiş Ayar';it = 'Impostazione Avanzate';de = 'Erweiterte Einstellung'"), Undefined);
	Close();
EndProcedure

#EndRegion
