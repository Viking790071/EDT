#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ParametersToGet = New Structure("DumpsInformation, DumpInstances, DumpInstancesApproved");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(ParametersToGet);
	DumpsInformation = MonitoringCenterParameters.DumpsInformation;
	Items.DumpsInformation.Height = StrLineCount(DumpsInformation);
	DumpsData = New Structure;
	DumpsData.Insert("DumpInstances", MonitoringCenterParameters.DumpInstances);
	DumpsData.Insert("DumpInstancesApproved", MonitoringCenterParameters.DumpInstancesApproved);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Yes(Command)
	Response1 = New Structure;
	Response1.Insert("Consistent", True);
	Response1.Insert("DumpsInformation", DumpsInformation);
	Response1.Insert("DoNotAskAgain", DoNotAskAgain);
	Response1.Insert("DumpInstances", DumpsData.DumpInstances);
	Response1.Insert("DumpInstancesApproved", DumpsData.DumpInstancesApproved);	
	SetMonitoringCenterParameters(Response1);
	Close();
EndProcedure

&AtClient
Procedure None(Command)
	Response1 = New Structure;
	Response1.Insert("Consistent", False);
	Response1.Insert("DoNotAskAgain", DoNotAskAgain);
	SetMonitoringCenterParameters(Response1);
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure SetMonitoringCenterParameters(Response)
	
	NewParameters = New Structure;
	
	If Response.Consistent Then
		
		If Response.DoNotAskAgain Then
			NewParameters.Insert("RequestConfirmationBeforeSending", False);
		EndIf;
		
		ParametersToGet = New Structure("DumpsInformation, DumpInstances");
		MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(ParametersToGet);
		
		NewParameters.Insert("DumpInstancesApproved", Response.DumpInstancesApproved);
		For Each Record In Response.DumpInstances Do
			NewParameters.DumpInstancesApproved.Insert(Record.Key, Record.Value);
			MonitoringCenterParameters.DumpInstances.Delete(Record.Key);
		EndDo;
		
		NewParameters.Insert("DumpInstances", MonitoringCenterParameters.DumpInstances);
		
		If Response.DumpsInformation = MonitoringCenterParameters.DumpsInformation Then
			NewParameters.Insert("DumpsInformation", "");	
		EndIf;
		
	Else
		
		If Response.DoNotAskAgain Then
			NewParameters.Insert("SendDumpsFiles", 0);
			NewParameters.Insert("SendingResult", NStr("ru = 'Пользователь отказал в предоставлении полных дампов.';
																|en = 'User refused to submit full dumps.';pl = 'Użytkownik odmówił przesyłania pełnych zrzutów.';es_ES = 'El usuario se negó a enviar los volcados por completo.';es_CO = 'El usuario se negó a enviar los volcados por completo.';tr = 'Kullanıcı tam döküm göndermeyi reddetti.';it = 'L''utente ha rifiutato di trasmettere i dump interi.';de = 'Der Benutzer lehnte Einreichen von vollen Dumps ab.'"));
			NewParameters.Insert("DumpsInformation", "");
			NewParameters.Insert("DumpInstances", New Map);
		EndIf;
		
	EndIf;
	
	MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(NewParameters);
	
EndProcedure

#EndRegion
