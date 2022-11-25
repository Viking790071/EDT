#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Executes preliminary control.
//
Procedure RunPreliminaryControl(Cancel)
	
	Query = New Query;
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("Period", Date);
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	
	// Check property states.
	Query.Text =
	"SELECT ALLOWED
	|	FixedAssetStateSliceLast.FixedAsset AS FixedAsset
	|FROM
	|	InformationRegister.FixedAssetStatus.SliceLast(&Period, Company = &Company) AS FixedAssetStateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	FixedAssetStateSliceLast.FixedAsset AS FixedAsset
	|FROM
	|	InformationRegister.FixedAssetStatus.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND FixedAsset IN (&FixedAssetsList)
	|				AND State = VALUE(Enum.FixedAssetStatus.AcceptedForAccounting)) AS FixedAssetStateSliceLast";
	
	ResultsArray = Query.ExecuteBatch();
	
	ArrayVAStatus = ResultsArray[0].Unload().UnloadColumn("FixedAsset");
	ArrayVAAcceptedForAccounting = ResultsArray[1].Unload().UnloadColumn("FixedAsset");
	
	For Each RowOfFixedAssets In FixedAssets Do
			
		If ArrayVAStatus.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The current status for the %1 fixed asset specified in the %2 line of the ""Fixed assets"" list is ""Not recognized"".'; ru = 'Для основного средства %1 указанного в строке %2 списка ""Основные средства"", текущий статус ""Не поставлен на учет"".';pl = 'Bieżący status środka trwałego %1 z wiersza nr %2 listy ""Środki trwałe"" to ""Nieprzyjęty"".';es_ES = 'El estado actual para el %1 activo fijo especificado en la %2 línea de la lista de ""Activos fijos"" es ""No reconocido"".';es_CO = 'El estado actual para el %1 activo fijo especificado en la %2 línea de la lista de ""Activos fijos"" es ""No reconocido"".';tr = '""Sabit kıymetler"" listesinin %2 satırında belirtilen %1 sabit kıymetin mevcut durumu ""Tanınmadı"" şeklindedir.';it = 'Lo stato corrente per il cespite  %1 specificato nella linea %2 dell''elenco ""Cespiti"" è ""Non riconosciuto"".';de = 'Der aktuelle Status des %1 Anlagevermögens, der in der %2 Zeile der Liste ""Anlagevermögen"" angegeben ist, lautet ""Nicht erkannt"".'"),
				TrimAll(String(RowOfFixedAssets.FixedAsset)),
				String(RowOfFixedAssets.LineNumber));
				
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel);
				
		ElsIf ArrayVAAcceptedForAccounting.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The current status for the %1 specified in the %2 line of the ""Fixed assets"" list is ""Not recognized"".'; ru = 'Для основного средства %1 указанного в строке %2 списка ""Основные средства"", текущий статус ""Не поставлен на учет"".';pl = 'Bieżący status środka trwałego %1 z wiersza nr %2 listy ""Środki trwałe"" to ""Nieprzyjęty"".';es_ES = 'El estado actual para el %1 especificado en la %2 línea de la lista de ""Activos fijos"" es ""No reconocido"".';es_CO = 'El estado actual para el %1 especificado en la %2 línea de la lista de ""Activos fijos"" es ""No reconocido"".';tr = '""Sabit kıymetler"" listesinin %2 satırında belirtilen %1''nin mevcut durumu ""Tanınmadı"" şeklindedir.';it = 'Lo stato corrente per il %1 specificato nella linea %2 dell''elenco ""Cespiti"" è ""Non riconosciuto"".';de = 'Der aktuelle Status für den in der %2 Zeile der Liste ""Anlagevermögen"" %1 angegebenen ist ""Nicht erkannt"".'"),
				TrimAll(String(RowOfFixedAssets.FixedAsset)),
				String(RowOfFixedAssets.LineNumber));
				
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel);
				
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssets(FillingData)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	DepreciationParametersSliceLast.Recorder.Company AS Company
	|FROM
	|	InformationRegister.FixedAssetParameters.SliceLast(, FixedAsset = &FixedAsset) AS DepreciationParametersSliceLast";
	
	Query.SetParameter("FixedAsset", FillingData);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Company = Selection.Company;
	EndIf;
	
	NewRow = FixedAssets.Add();
	NewRow.FixedAsset = FillingData;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.FixedAssets") Then
		FillByFixedAssets(FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Preliminary control execution.
	RunPreliminaryControl(Cancel);
	
	For Each RowOfFixedAssets In FixedAssets Do
			
		If RowOfFixedAssets.FixedAsset.DepreciationMethod <> Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Depreciation method other than ""Units-of-production"" is used for %1 specified in the %2 line of the ""Fixed assets"" list.'; ru = 'Для %1 указанного в строке %2 списка ""Основные средства"", используется способ начисления амортизации отличный от ""Пропорционально объему продукции (работ)"".';pl = 'Metoda naliczenia amortyzacji używana dla %1 w wierszu %2 listy ""Środki trwałe"" jest inna, niż ""Proporcjonalnie do wyrobów gotowych"".';es_ES = 'El método de depreciación distinto de ""Unidades-de-producción"" se ha usado para %1 especificado en la %2 línea de la lista de ""Activos fijos"".';es_CO = 'El método de depreciación distinto de ""Unidades-de-producción"" se ha usado para %1 especificado en la %2 línea de la lista de ""Activos fijos"".';tr = '""Üretim birimleri"" dışındaki amortisman yöntemi, ""Sabit kıymetler"" listesinin %2satırında belirtilen %1için kullanılır.';it = 'Il metodo di ammortamento diverso da ""Unità di produzione"" è usato per %1 specificato nella linea %2 dell''elenco ""Cespiti"".';de = 'Für %1, das in der %2 Zeile der Liste ""Anlagevermögen"" angegeben ist, wird eine andere Abschreibungsmethode als ""Produktionseinheiten"" verwendet.'"),
				TrimAll(String(RowOfFixedAssets.FixedAsset)),
				String(RowOfFixedAssets.LineNumber));
				
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.FixedAssetUsage.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectFixedAssetUsage(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
EndProcedure

#EndRegion

#EndIf