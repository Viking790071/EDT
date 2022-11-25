#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("StructuralUnitType");
	
	Return Result;
	
EndFunction

Function AccountingByBusinessUnits() Export
	// Until "Business units" dimension is enabled for "Accounting journal entries"
	Return False;
EndFunction

Function DepartmentReadingAllowed(Ref) Export
	
	ReadingAllowed = True;
	
	If ValueIsFilled(Ref) Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	BusinessUnits.Ref AS Ref
		|FROM
		|	Catalog.BusinessUnits AS BusinessUnits
		|WHERE
		|	BusinessUnits.Ref = &Department";
		
		Query.SetParameter("Department", Ref);
		
		QueryResult = Query.Execute();
		
		ReadingAllowed = Not QueryResult.IsEmpty();
		
	EndIf;
	
	Return ReadingAllowed;
	
EndFunction

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes.
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("StructuralUnitType");
	AttributesToLock.Add("Parent");
	AttributesToLock.Add("Company");
	AttributesToLock.Add("RetailPriceKind");
	AttributesToLock.Add("FRP");
	AttributesToLock.Add("PlanningInterval");
	AttributesToLock.Add("PlanningIntervalDuration");
	
	Return AttributesToLock;
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.BusinessUnits);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	User = Users.CurrentUser();
	
	If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
		If FormType = "ChoiceForm" Then
			StandardProcessing = False;
			SelectedForm = "ChoiceFormForExternalUsers";
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

#Region InfobaseUpdate

Procedure FillRequiredAttributes() Export 
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	DefaultCompany = Catalogs.Companies.MainCompany;
	DefaultStructuralUnitType = Enums.BusinessUnitsTypes.Warehouse;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	BusinessUnits.Ref AS Ref
	|FROM
	|	Catalog.BusinessUnits AS BusinessUnits
	|WHERE
	|	BusinessUnits.Ref IN (VALUE(Catalog.BusinessUnits.GoodsInTransit), VALUE(Catalog.BusinessUnits.DropShipping))
	|	AND BusinessUnits.Company = VALUE(Catalog.Companies.EmptyRef)";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do 
		
		BusinessUnit = Selection.Ref.GetObject();
		If BusinessUnit = Undefined Then
			Continue;
		EndIf;
		
		BusinessUnit.Company = DefaultCompany;
		BusinessUnit.StructuralUnitType = DefaultStructuralUnitType;
		
		Try 
			InfobaseUpdate.WriteObject(BusinessUnit);
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t save catalog item ""%1"". Details: %2.'; ru = 'Не удалось записать элемент ""%1"". Подробнее: %2.';pl = 'Nie udało się zapisać elementu katalogu ""%1"". Szczegóły: %2.';es_ES = 'No se ha podido guardar el artículo del catálogo ""%1"". Detalles: %2.';es_CO = 'No se ha podido guardar el artículo del catálogo ""%1"". Detalles: %2.';tr = '""%1"" katalog öğesi saklanamadı. Ayrıntılar: %2.';it = 'Impossibile salvare l''elemento ""%1"" del catalogo. Dettagli: %2.';de = 'Fehler beim Speichern der Katalogposition ""%1"". Details: %2.'", DefaultLanguageCode),
				BusinessUnit,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Catalogs.BusinessUnits,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure ClearRequiredAttributes() Export 
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	EmptyRef = Catalogs.Companies.EmptyRef();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	BusinessUnits.Ref AS Ref
	|FROM
	|	Catalog.BusinessUnits AS BusinessUnits
	|WHERE
	|	BusinessUnits.Ref IN (VALUE(Catalog.BusinessUnits.GoodsInTransit), VALUE(Catalog.BusinessUnits.DropShipping))
	|	AND NOT BusinessUnits.Company = VALUE(Catalog.Companies.EmptyRef)";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do 
		
		BusinessUnit = Selection.Ref.GetObject();
		If BusinessUnit = Undefined Then
			Continue;
		EndIf;
		
		BusinessUnit.Company = EmptyRef;
		
		Try 
			InfobaseUpdate.WriteObject(BusinessUnit);
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn't save catalog item ""%1"". Details: %2.'", DefaultLanguageCode),
				BusinessUnit,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Catalogs.BusinessUnits,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf