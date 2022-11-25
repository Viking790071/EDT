
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not IsBlankString(Parameters.NoteText) Then
		Items.NoteDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1
			           |Установить?'; 
			           |en = '%1
			           |Do you want to install the extension?'; 
			           |pl = '%1
			           |Ustawić?';
			           |es_ES = '%1
			           |¿Quiere instalar la extensión?';
			           |es_CO = '%1
			           |¿Quiere instalar la extensión?';
			           |tr = '%1
			           |Ayarla?';
			           |it = '%1
			           |Impostare?';
			           |de = '%1
			           |Installieren?'"),
			Parameters.NoteText);
	EndIf;
	
EndProcedure

#EndRegion