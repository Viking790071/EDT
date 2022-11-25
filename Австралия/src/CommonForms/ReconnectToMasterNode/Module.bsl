
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	MasterNode = Constants.MasterNode.Get();
	
	If Not ValueIsFilled(MasterNode) Then
		Raise NStr("ru = 'Главный узел не сохранен.'; en = 'The master node is not saved.'; pl = 'Główny węzeł nie został zapisany.';es_ES = 'Nodo principal no se ha guardado.';es_CO = 'Nodo principal no se ha guardado.';tr = 'Ana ünite kaydedilmedi.';it = 'Il nodo principale non è stato salvato.';de = 'Hauptknoten wird nicht gespeichert.'");
	EndIf;
	
	If ExchangePlans.MasterNode() <> Undefined Then
		Raise NStr("ru = 'Главный узел установлен.'; en = 'The master node is set.'; pl = 'Główny węzeł jest ustawiony.';es_ES = 'Nodo principal está establecido.';es_CO = 'Nodo principal está establecido.';tr = 'Ana ünite belirlendi.';it = 'Il nodo principale è stato salvato.';de = 'Hauptknoten ist gesetzt.'");
	EndIf;
	
	Items.WarningText.Title = StringFunctionsClientServer.SubstituteParametersToString(
		Items.WarningText.Title, String(MasterNode));
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Reconnect(Command)
	
	ReconnectAtServer();
	
	Close(New Structure("Cancel", False));
	
EndProcedure

&AtClient
Procedure Disable(Command)
	
	DisconnectAtServer();
	
	Close(New Structure("Cancel", False));
	
EndProcedure

&AtClient
Procedure ExitApplication(Command)
	
	Close(New Structure("Cancel", True));
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure DisconnectAtServer()
	
	BeginTransaction();
	Try
		MasterNode = Constants.MasterNode.Get();
		
		MasterNodeManager = Constants.MasterNode.CreateValueManager();
		MasterNodeManager.Value = Undefined;
		InfobaseUpdate.WriteData(MasterNodeManager);
		
		IsStandaloneWorkplace = Constants.IsStandaloneWorkplace.CreateValueManager();
		IsStandaloneWorkplace.Read();
		If IsStandaloneWorkplace.Value Then
			IsStandaloneWorkplace.Value = False;
			InfobaseUpdate.WriteData(IsStandaloneWorkplace);
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
			ModuleDataExchangeServer.DeleteSynchronizationSettingsForMasterDIBNode(MasterNode);
		EndIf;
		
		StandardSubsystemsServer.RestorePredefinedItems();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServerNoContext
Procedure ReconnectAtServer()
	
	MasterNode = Constants.MasterNode.Get();
	
	ExchangePlans.SetMasterNode(MasterNode);
	
EndProcedure

#EndRegion
