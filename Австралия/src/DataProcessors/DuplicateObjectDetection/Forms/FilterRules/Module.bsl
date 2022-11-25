// The following parameters are expected:
//
//     MasterFormID - UUID - ID of the form through which exchange is performed.
//                                                                 
//     CompositionSchemaAddress - Row - address of the temporary storage with composition schema 
//                                                whose settings are edited.
//     FilterComposerSettingsAddress - Row - address of the temporary storage with editable composer settings.
//     FilterAreaPresentation - Row - presentation for title generation.
//
// Returns the selection result:
//
//     Undefined - to cancel editing.
//     Row - address of the temporary storage with new composer settings.
//

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	MasterFormID = Parameters.MasterFormID;
	
	PrefilterComposer = New DataCompositionSettingsComposer;
	PrefilterComposer.Initialize( 
		New DataCompositionAvailableSettingsSource(Parameters.CompositionSchemaAddress) );
		
	FilterComposerSettingsAddress = Parameters.FilterComposerSettingsAddress;
	PrefilterComposer.LoadSettings(GetFromTempStorage(FilterComposerSettingsAddress));
	DeleteFromTempStorage(FilterComposerSettingsAddress);
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Правила отбора ""%1""'; en = 'Filter rules ""%1""'; pl = 'Reguły filtrów wyboru ""%1""';es_ES = 'Reglas del filtro ""%1""';es_CO = 'Reglas del filtro ""%1""';tr = '""%1"" kurallarını filtrele';it = 'Regole di filtro ""%1""';de = 'Filterregeln ""%1""'"), Parameters.FilterAreaPresentation);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	If Modified Then
		NotifyChoice(FilterComposerSettingsAddress());
	Else
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function FilterComposerSettingsAddress()
	Return PutToTempStorage(PrefilterComposer.Settings, MasterFormID)
EndFunction

#EndRegion

