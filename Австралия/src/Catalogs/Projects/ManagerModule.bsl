#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region LibrariesHandlers

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export
	
EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	AttributesToLock.Add("Parent");
	AttributesToLock.Add("Counterparty");
	AttributesToLock.Add("Contract");
	AttributesToLock.Add("Company");
	
	If GetFunctionalOption("UseProjectManagement") Then
		AttributesToLock.Add("Subject");
		AttributesToLock.Add("Manager");
		AttributesToLock.Add("DurationUnit");
		AttributesToLock.Add("WorkSchedule");
	EndIf;
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.Projects);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillDurationUnit() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Projects.Ref AS Ref
	|FROM
	|	Catalog.Projects AS Projects
	|WHERE
	|	Projects.DurationUnit = VALUE(Enum.DurationUnits.EmptyRef)
	|	AND NOT Projects.DeletionMark";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		ProjectObject = Selection.Ref.GetObject();
		ProjectObject.DurationUnit = Enums.DurationUnits.Day;
		
		Try
			
			InfobaseUpdate.WriteObject(ProjectObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = '???? ?????????????? ???????????????? ???????????????????? ""%1"". ??????????????????: %2';pl = 'Nie mo??na zapisa?? katalogu ""%1"". Szczeg????y: %2';es_ES = 'Ha ocurrido un error al guardar el cat??logo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el cat??logo ""%1"". Detalles: %2';tr = '""%1"" katalo??u saklanam??yor. Ayr??nt??lar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Catalogs.Projects,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf