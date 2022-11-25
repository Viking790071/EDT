
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var PreviousValue;

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	PreviousValue = Constants.LimitAccessAtRecordLevelUniversally.Get();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Value <> PreviousValue Then // Changed.
		// Updating session parameters.
		// It is required so that the administrator does not have to restart.
		SpecifiedParameters = New Array;
		AccessManagementInternal.SessionParametersSetting("", SpecifiedParameters);
	EndIf;
	
	If Value AND Not PreviousValue Then // Enabled.
		If Not Constants.LimitAccessAtRecordLevel.Get() Then
			ErrorText =
				NStr("ru = 'Чтобы включить константу ""Ограничивать доступ на уровне записей универсально""
				           |сначала нужно включить константу ""Ограничивать доступ на уровне записей"".'; 
				           |en = 'To enable the ""Limit access at record level universally"" constant,
				           |first enable the ""Limit access at record level"" constant.'; 
				           |pl = 'Aby włączyć stały poziom ""Ogranicz dostęp do rekordu na poziomie""
				           |, należy najpierw włączyć stałą ""Ogranicz dostęp do rekordu"".';
				           |es_ES = 'Para activar el constante ""Restringir el acceso en nivel de registros es universal""
				           |primero hay que activar el constante ""Restringir el acceso en nivel de registros"".';
				           |es_CO = 'Para activar el constante ""Restringir el acceso en nivel de registros es universal""
				           |primero hay que activar el constante ""Restringir el acceso en nivel de registros"".';
				           |tr = '""Kayıt seviyelerinde üniversal olarak erişim kısıtlansın"" sabitin devreye girmesi için 
				           |önceden ""Kayıtlar seviyesinde erişimi kısıtla"" sabiti aktif hale getirilmelidir.';
				           |it = 'Per attivare la costante ""Limita l''accesso a livello di record universalmente"",
				           |attivare prima la costante ""Limita accesso a livello di record"".';
				           |de = 'Um die Konstante ""Zugriff auf die Aufzeichnungsebene allgemein einschränken"" zu aktivieren, müssen Sie
				           |zuerst die Konstante ""Zugriff auf die Aufzeichnungsebene einschränken"" aktivieren.'");
			Raise ErrorText;
		EndIf;
		ValueManager = Constants.LastAccessUpdate.CreateValueManager();
		ValueManager.Value = New ValueStorage(Undefined);
		InfobaseUpdate.WriteData(ValueManager);
		RecordSet = InformationRegisters.AccessRestrictionParameters.CreateRecordSet();
		InfobaseUpdate.WriteData(RecordSet);
		
		AccessManagementInternal.ScheduleAccessUpdate();
		AccessManagementInternal.SetAccessUpdate(True);
	EndIf;
	
	If Not Value AND PreviousValue Then // Disabled.
		AccessManagementInternal.EnableDataFillingForAccessRestriction();
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
