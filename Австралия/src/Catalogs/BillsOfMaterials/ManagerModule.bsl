#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetBOMByDefault(ProductOwner) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Products.Specification AS BillOfMaterials
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	Products.Ref = &Owner";
	
	Query.SetParameter("Owner", ProductOwner);
	
	QueryResult = Query.Execute();
	
	SelectionBills = QueryResult.Select();
	
	While SelectionBills.Next() Do
		Return SelectionBills.BillOfMaterials;
	EndDo;
	
	Return Catalogs.BillsOfMaterials.EmptyRef();

EndFunction

Function GetAvailableBOM(ProductOwner, ValidDate, ProductCharacteristic = Undefined, OperationTypeAsIs = Undefined, ExcludeByProducts = False) Export
	
	CheckCharacteristic	= False;
	QueryResult			= Undefined;
	OperationKind		= Undefined;
	IsExecuteQuery		= False;
	
	Query = New Query;
	
	Query.Text = GetQueryTextDefaultBOM();
	
	Query.SetParameter("ValidDate", ValidDate);
	Query.SetParameter("EmptyDate", Date(1,1,1));
	Query.SetParameter("ProductOwner", ProductOwner);
	Query.SetParameter("StatusActive", Enums.BOMStatuses.Active);
	Query.SetParameter("ExcludeByProducts", ExcludeByProducts);
	
	If Not ProductCharacteristic = Undefined Then
		CheckCharacteristic = IsBillsWithCharacteristic(ProductCharacteristic, Query, QueryResult);
	EndIf;
	
	If ValueIsFilled(OperationTypeAsIs) Then
		
		OperationTypeOrder = BOMOperationKind(OperationTypeAsIs);
		
		Query.Text = GetQueryTextDefaultBOMWithOperationKind();
		Query.SetParameter("OperationTypesOrder", OperationTypeOrder);
		
		IsExecuteQuery = True;
		
	EndIf;
	
	If Not CheckCharacteristic Then
		
		Query.SetParameter("NotCheckCharacteristic", True);
		Query.SetParameter("ProductCharacteristic", Catalogs.ProductsCharacteristics.EmptyRef());
		
		IsExecuteQuery = True;
		
		
	EndIf;
	
	If IsExecuteQuery Then
		
		QueryResult = Query.Execute();
		
	EndIf;
	
	SelectionBills = QueryResult.Select();
	
	Result = Catalogs.BillsOfMaterials.EmptyRef();
	
	If SelectionBills.Count() = 1 Then
		
		While SelectionBills.Next() Do
			
			Result = SelectionBills.BOM;
			
			If ValueIsFilled(OperationTypeOrder) Then
				OperationKind = SelectionBills.OperationKind;
			EndIf;
			
			Break;
			
		EndDo;
		
	ElsIf SelectionBills.Count() > 1 Then
		
		While SelectionBills.Next() Do
			
			If SelectionBills.BOM = SelectionBills.MainBOM Then
				
				Result = SelectionBills.BOM;
				
				If ValueIsFilled(OperationTypeOrder) Then
					OperationKind = SelectionBills.OperationKind;
				EndIf;
				
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If ValueIsFilled(OperationTypeOrder) And TypeOf(OperationTypeOrder) <> Type("Array") Then
		
		If Not OperationKind = OperationTypeOrder Then
			Result = Catalogs.BillsOfMaterials.EmptyRef();
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function CheckOperationsTableForDifferentDepartments(OperationsTable) Export
	
	ErrorMessage = "";
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	OperationsTable.LineNumber AS LineNumber,
		|	OperationsTable.Activity AS Activity
		|INTO OperationsTable
		|FROM
		|	&OperationsTable AS OperationsTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OperationsTable.LineNumber AS LineNumber,
		|	OperationsTable.Activity AS Activity,
		|	CompanyResourceTypes.Ref AS WorkcenterType,
		|	CompanyResourceTypes.BusinessUnit AS BusinessUnit
		|FROM
		|	OperationsTable AS OperationsTable
		|		INNER JOIN Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
		|		ON OperationsTable.Activity = ManufacturingActivitiesWorkCenterTypes.Ref
		|		INNER JOIN Catalog.CompanyResourceTypes AS CompanyResourceTypes
		|		ON (CompanyResourceTypes.Ref = ManufacturingActivitiesWorkCenterTypes.WorkcenterType)
		|
		|ORDER BY
		|	LineNumber";
	
	Query.SetParameter("OperationsTable", OperationsTable);
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	BusinessUnitsArray = New Array;
	
	While SelectionDetailRecords.Next() Do
		
		If ValueIsFilled(SelectionDetailRecords.BusinessUnit) Then
			
			BusinessUnitsArray.Add(SelectionDetailRecords.BusinessUnit);
			LineErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '#%1, operation %2 assigned with work center type %3, which belongs to the %4 department.'; ru = '??? %1, ???????????????? %2 ???????????????? ?????? ???????????????? ???????????? %3, ?????????????? ?????????????????????? ?????????????????????????? %4.';pl = 'nr %1, operacja %2 przypisana do tego typu gniazda produkcyjnego %3, kt??ry nale??y do dzia??u %4.';es_ES = '#%1, operaci??n %2 asignada con el tipo de centro de trabajo %3, que pertenece al %4 departamento.';es_CO = '#%1, operaci??n %2 asignada con el tipo de centro de trabajo %3, que pertenece al %4 departamento.';tr = '#%1, i??lem %2, %3 i?? merkezi t??r??yle atand??, %4 b??l??m??ne ait.';it = '#%1, operazione %2 assegnata con tipo di centro di lavoro %3, del reparto %4.';de = 'Nr.%1, Operation %2 zugewiesen mit dem Typ des Arbeitsabschnitts %3, der zur Abteilung %4 geh??rt.'"),
				SelectionDetailRecords.LineNumber,
				SelectionDetailRecords.Activity,
				SelectionDetailRecords.WorkcenterType,
				SelectionDetailRecords.BusinessUnit);
			ErrorMessage = ErrorMessage + LineErrorMessage + Chars.LF;
			
		EndIf;
		
	EndDo;
	
	BusinessUnitsArray = CommonClientServer.CollapseArray(BusinessUnitsArray);
	
	If BusinessUnitsArray.Count() < 2 Then
		ErrorMessage = "";
	EndIf;
	
	Return ErrorMessage;
	
EndFunction

Function CheckBillsOfMaterialsOperationsTable(BillsOfMaterials) Export
	
	MessageAboutError = "";
	
	BOMOperationsQueryResult = Common.ObjectAttributeValue(BillsOfMaterials, "Operations");
	If BOMOperationsQueryResult <> Undefined Then
		BOMOperations = BOMOperationsQueryResult.Unload();
		
		DifferentDepartmentsMessage = CheckOperationsTableForDifferentDepartments(BOMOperations);
		If DifferentDepartmentsMessage <> "" Then
			
			ErrorMessageTemplate = NStr("en = 'Couldn''t select BOM ""%1"". 
				|Its operations are assigned with work center types that belong to different business units:'; 
				|ru = '???? ?????????????? ?????????????? ???????????????????????? ""%1"". 
				|???? ???????????????? ?????????????????? ?????????? ?????????????? ??????????????, ???????????????? ?? ???????????? ??????????????????????????:';
				|pl = 'Nie uda??o si?? wybra?? specyfikacji materia??owej ""%1"". 
				|Operacje z niej s?? przypisane do typ??w gniazd produkcyjnych, kt??re nale???? do r????nych jednostek biznesowych:';
				|es_ES = 'No se pudo seleccionar la lista de materiales ""%1"". 
				|Sus operaciones est??n asignadas con tipos de centros de trabajo que pertenecen a diferentes unidades empresariales:';
				|es_CO = 'No se pudo seleccionar la lista de materiales ""%1"". 
				|Sus operaciones est??n asignadas con tipos de centros de trabajo que pertenecen a diferentes unidades empresariales:';
				|tr = '""%1"" ??r??n re??etesi se??ilemedi. 
				|????lemleri, farkl?? departmanlara ait i?? merkezi t??rleriyle atanm????:';
				|it = 'Impossibile selezionare la distinta base ""%1"".
				|Le sue operazioni sono assegnate con tipi di centro di lavoro che appartengono a diverse business unit:';
				|de = 'Fehler beim Auswahl einer St??ckliste ""%1"".
				|Deren Operationen sind den Typen von Arbeitsabschnitten zugewiesen, die zu verschiedenen Abteilungen geh??ren:'");
			
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate, BillsOfMaterials);
			
			ErrorMessage = ErrorMessage
				+ DifferentDepartmentsMessage
				+ NStr("en = 'Please select operations assigned with work center types that belong to the same business units.'; ru = '???????????????? ????????????????, ?????????????????????? ?????????? ?????????????? ??????????????, ???????????????? ?? ???????? ??????????????????????????.';pl = 'Wybierz operacje przypisane do typ??w gniazd produkcyjnych, kt??re nale???? do tych samych jednostek biznesowych.';es_ES = 'Por favor, seleccione las operaciones asignadas con tipos de centros de trabajo que pertenezcan a las mismas unidades empresariales.';es_CO = 'Por favor, seleccione las operaciones asignadas con tipos de centros de trabajo que pertenezcan a las mismas unidades empresariales.';tr = 'L??tfen, ayn?? departmanlara ait i?? merkezi t??rleriyle atanm???? i??lemler se??in.';it = 'Selezionare le operazioni assegnate con i tipi di centro di lavoro che appartengono alla stessa business unit.';de = 'Bitte w??hlen Sie die den Typen von Arbeitsabschnitten zugewiesenen Operationen aus, die zu verschiedenen Abteilungen geh??ren.'");
			
			MessageAboutError = ErrorMessage;
			
		EndIf;
		
	EndIf;

	Return MessageAboutError;
	
EndFunction

Procedure CheckBOMLevel(BOMRef, Cancel) Export
	
	MaxNumberOfBOMLevels = Constants.MaxNumberOfBOMLevels.Get();
	LevelsUpCount = 1;
	
	UpToRoot(BOMRef, LevelsUpCount, LevelsUpCount, MaxNumberOfBOMLevels);
	
	Query = New Query;
	Query.SetParameter("Ref", BOMRef);
	Query.Text =
	"SELECT DISTINCT
	|	BOMContent.Specification AS Specification
	|INTO BOMLevel_0
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BOMContent
	|WHERE
	|	BOMContent.Ref = &Ref";
	
	QueryTextFragment1 = "";
	QueryTextFragment2 = DriveClientServer.GetQueryDelimeter();
	
	For i = 1 To MaxNumberOfBOMLevels Do
		
		Text1 = DriveClientServer.GetQueryDelimeter() + "
			|SELECT DISTINCT
			|	BillsOfMaterialsContent.Specification AS Specification,
			|	%3 AS Level
			|INTO %1
			|FROM
			|	%2 AS BOMTable
			|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
			|		ON BOMTable.Specification = BillsOfMaterialsContent.Ref
			|		AND (BOMTable.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef))";
		
		QueryTextFragment1 = QueryTextFragment1 + StrTemplate(Text1, "BOMLevel_" + String(i), "BOMLevel_" + String(i-1), String(i));
		
		Text2 = ?(i = 1, "", DriveClientServer.GetQueryUnion()) + "
			|SELECT
			|	BOMTable.Level
			|%2
			|FROM
			|	%1 AS BOMTable";
		
		QueryTextFragment2 = QueryTextFragment2 + StrTemplate(Text2, "BOMLevel_" + String(i), ?(i = 1, "INTO BOMLevelTable", ""));
		
	EndDo;
	
	Query.Text = Query.Text + QueryTextFragment1 + QueryTextFragment2 + DriveClientServer.GetQueryDelimeter() + "
		|SELECT
		|	ISNULL(MAX(BOMLevelTable.Level), 0) AS Level
		|FROM
		|	BOMLevelTable AS BOMLevelTable";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		MaxLevel = Selection.Level + LevelsUpCount;
		If MaxLevel > MaxNumberOfBOMLevels Then
			
			MessageText = NStr("en = 'The number of BOM levels (%1) cannot exceed the max number of BOM levels (%2) specified in Settings. Do either of the following:
								|- Open the BOM explosion and BOM implosion report. Review the BOM structure. Then edit this BOM and the related BOMs so that the structure of this BOM includes fewer levels. For example, in this BOM, replace a component with a component whose BOM is single-level.
								|- Go to Settings > Production > Other and increase the Max number of BOM levels.
								|Then try again.'; 
								|ru = '???????????????????? ?????????????? ???????????????????????? (%1) ???? ?????????? ?????????????????? ???????????????????????? ???????????????????? ?????????????? ???????????????????????? (%2), ?????????????????? ?? ????????????????????. ?????????????????? ???????? ???? ?????????????????? ????????????????:
								|- ???????????????? ???????????? ""???????????????? ????????????????????????"" ?? ""?????????????????? ?? ??????????????????????????"" ?? ?????????????? ?????????????????? ????????????????????????. ?????????? ???????????????????????????? ?????? ???????????????????????? ?? ?????????????????? ?? ?????? ????????????????????????, ?????????? ?????????????????? ???????? ???????????????????????? ???????????????? ???????????? ??????????????. ????????????????, ???????????????? ???????? ???? ?????????????????????? ???? ?????????????????? ?? ?????????????????????????? ??????????????????????????.
								|- ?????????????????? ?? ?????????????????? > ???????????????????????? > ???????????? ?? ?????????????????? ???????????????????????? ???????????????????? ?????????????? ????????????????????????.
								|?????????? ?????????????????? ??????????????.';
								|pl = 'Ilo???? poziom??w specyfikacji materia??owej (%1) nie mo??e przekracza?? maksymalnej ilo??ci poziom??w specyfikacji materia??owej, (%2) okre??lonej w Ustawieniach. Wykonaj jedn?? z czynno??ci:
								|- Otw??rz raporty Podzia?? specyfikacji materia??owej i Komponent w specyfikacjach materia??owych. Zapoznaj si?? ze struktur?? specyfikacji materia??owej. Nast??pnie edytuj t?? specyfikacj?? materia??ow?? i powi??zane specyfikacje materia??owe tak aby struktura tej specyfikacji materia??owej obejmowa??a mniej poziom??w. Na przyk??ad, w tej specyfikacji materia??owej zast??p jeden z komponent??w komponentem z jednopoziomow?? specyfikacj?? materia??ow??.
								|- Przejd?? do Ustawienia > Produkcja > Inne i zwi??ksz maksymaln?? ilo???? poziom??w specyfikacji materia??owej.
								|Nast??pnie spr??buj ponownie.';
								|es_ES = 'El n??mero de niveles de la lista de materiales (%1) no puede superar el n??mero m??ximo de niveles de la lista de materiales (%2) especificado en Configuraci??n. Realice una de las siguientes acciones:
								|- Abra el informe de explosi??n e implosi??n de la lista de materiales. Revise la estructura de la lista de materiales. A continuaci??n, edite esta lista de materiales y las listas de materiales relacionadas para que la estructura de esta lista de materiales incluya menos niveles. Por ejemplo, en esta lista de materiales, sustituya un componente por otro cuya lista de materiales sea de un solo nivel.
								|- Vaya a Configuraciones > Producci??n > Otro y aumente el N??mero m??ximo de niveles de la lista de materiales.
								|A continuaci??n, vuelva a intentarlo.';
								|es_CO = 'El n??mero de niveles de la lista de materiales (%1) no puede superar el n??mero m??ximo de niveles de la lista de materiales (%2) especificado en Configuraci??n. Realice una de las siguientes acciones:
								|- Abra el informe de explosi??n e implosi??n de la lista de materiales. Revise la estructura de la lista de materiales. A continuaci??n, edite esta lista de materiales y las listas de materiales relacionadas para que la estructura de esta lista de materiales incluya menos niveles. Por ejemplo, en esta lista de materiales, sustituya un componente por otro cuya lista de materiales sea de un solo nivel.
								|- Vaya a Configuraciones > Producci??n > Otro y aumente el N??mero m??ximo de niveles de la lista de materiales.
								|A continuaci??n, vuelva a intentarlo.';
								|tr = '??r??n re??etesi seviyelerinin say??s?? (%1) Ayarlar''da belirtilen maksimum ??r??n re??etesi seviyesi say??s??n?? (%2) a??amaz. ??unlardan birini yap??n:
								|- ??r??n re??etesi a????l??m??n?? ve ??r??n re??etesi a????l??m?? raporunu a????n. ??r??n re??etesi yap??s??n?? inceleyin. Ard??ndan, bu ??r??n re??etesinin daha az seviye i??erece??i ??ekilde bu ??r??n re??etesini ve ilgili ??r??n re??etelerini d??zenleyin. ??rne??in, bu ??r??n re??etesinde bir malzemeyi, ??r??n re??etesi tek seviyeli olan bir malzemeyle de??i??tirin.
								|- Ayarlar > ??retim > Di??er b??l??m??nde Maksimum ??r??n re??etesi seviyesini art??r??n.
								|Ard??ndan, tekrar deneyin.';
								|it = 'Il numero di livello della distinta base (%1) non pu?? superare il numero massimo di livelli della distinta base (%2) indicato in Impostazioni. Eseguire una delle seguenti azioni:
								|- Aprire i report di esplosione e implosione della distinta base. Rivedere la struttura della distinta base, poi modificare questa e la distinta base relativa, cos?? che la struttura della presente distinta base includa meno livelli. Ad esempio, sostituire una componente di questa distinta base con una componente la cui distinta base ha un solo livello.
								|- Andare in Impostazioni > Produzione > Altro e aumentare il Numero massimo di livelli della distinta base,
								|poi riprovare.';
								|de = 'Die Anzahl von St??cklistenebenen (%1) darf die H??chstanzahl von St??cklistenebenen (%2), angegeben in den Einstellungen, nicht ??berschreiten. F??hren Sie einen der folgenden Schritte surch:
								|- ??ffnen Sie den Bericht Entwicklung von St??ckliste und Verwendbarkeit von St??ckliste. ??berpr??fen Sie die St??cklistenstruktur. Dann bearbeiten Sie die verbundenen St??cklisten in der Weise dass die Struktur dieser St??ckliste geringere Stufen enth??lt. Z. B., ersetzen Sie in dieser St??ckliste eine Komponente durch eine Komponente mit einer einstufiger St??ckliste.
								|- Gehen Sie zu Einstellungen > Produktion > Sonstige und erh??hen die H??chstanzahl von St??cklistenstufen.
								|Dann versuchen Sie erneut.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, MaxLevel, MaxNumberOfBOMLevels);
			CommonClientServer.MessageToUser(MessageText, , , , Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillInBOMExplosionTree(Parameters, ResultAddress) Export
	
	Tree = Parameters.Tree;
	BillOfMaterials = Parameters.BillOfMaterials;
	MaxNumberOfBOMLevels = Constants.MaxNumberOfBOMLevels.Get();
	ShowOperations = Parameters.ShowOperations;
	ShowComponents = Parameters.ShowComponents;
	
	AddlParameters = New Structure("ShowOperations, ShowComponents", ShowOperations, ShowComponents);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	BillsOfMaterials.Owner AS Owner,
	|	BillsOfMaterials.ProductCharacteristic AS ProductCharacteristic,
	|	BillsOfMaterials.Quantity AS SpecificationQuantity,
	|	BillsOfMaterialsContent.Products AS Product,
	|	BillsOfMaterialsContent.Characteristic AS Characteristic,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	ISNULL(BillsOfMaterialsOperations.Quantity, 0) AS ActivityQuantity,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	BillsOfMaterialsContent.Activity AS Activity,
	|	BillsOfMaterialsContent.ActivityConnectionKey AS ConnectionKey
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		INNER JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
	|		ON BillsOfMaterialsContent.Ref = BillsOfMaterials.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON BillsOfMaterialsContent.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
	|		ON BillsOfMaterialsContent.Activity = BillsOfMaterialsOperations.Activity
	|			AND BillsOfMaterialsContent.Ref = BillsOfMaterialsOperations.Ref
	|			AND BillsOfMaterialsContent.ActivityConnectionKey = BillsOfMaterialsOperations.ConnectionKey
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON BillsOfMaterialsContent.MeasurementUnit = CatalogUOM.Ref
	|WHERE
	|	BillsOfMaterials.Ref = &BOM
	|
	|UNION ALL
	|
	|SELECT
	|	BillsOfMaterials.Owner,
	|	BillsOfMaterials.ProductCharacteristic,
	|	BillsOfMaterials.Quantity,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	BillsOfMaterialsOperations.Quantity,
	|	UNDEFINED,
	|	BillsOfMaterialsOperations.Activity,
	|	BillsOfMaterialsOperations.ConnectionKey
	|FROM
	|	Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
	|		INNER JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
	|		ON BillsOfMaterialsOperations.Ref = BillsOfMaterials.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON BillsOfMaterialsOperations.Activity = BillsOfMaterialsContent.Activity
	|			AND BillsOfMaterialsOperations.Ref = BillsOfMaterialsContent.Ref
	|WHERE
	|	BillsOfMaterials.Ref = &BOM
	|	AND BillsOfMaterialsContent.Activity IS NULL
	|TOTALS
	|	MAX(Owner),
	|	MAX(ProductCharacteristic),
	|	MAX(SpecificationQuantity),
	|	MAX(ActivityQuantity),
	|	MAX(Activity)
	|BY
	|	ConnectionKey";
	
	Query.SetParameter("BOM", BillOfMaterials);
	
	IsFirstRow = True;
	
	Pcs = Catalogs.UOMClassifier.pcs;
	
	SelectionActivity = Query.Execute().Select(QueryResultIteration.ByGroups);
	While SelectionActivity.Next() Do
		
		If IsFirstRow Then
			
			If ShowComponents Then
				LineProduct = Tree.Rows.Add();
				LineProduct.Product = SelectionActivity.Owner;
				LineProduct.Characteristic = SelectionActivity.ProductCharacteristic;
				LineProduct.BOMLevel = 0;
				LineProduct.Quantity = SelectionActivity.SpecificationQuantity;
				LineProduct.MeasurementUnit = Common.ObjectAttributeValue(SelectionActivity.Owner, "MeasurementUnit");
				LineProduct.BillOfMaterials = BillOfMaterials;
				LineProduct.BOMExplosion = SelectionActivity.Owner;
			Else
				LineProduct = Tree;
			EndIf;
		
			IsFirstRow = False;
			
		EndIf;
		
		If ShowOperations Then
			LineActivity = LineProduct.Rows.Add();
			LineActivity.BOMLevel = 1;
			LineActivity.Activity = SelectionActivity.Activity;
			LineActivity.Quantity = SelectionActivity.ActivityQuantity;
			LineActivity.MeasurementUnit = Pcs;
			LineActivity.BOMExplosion = SelectionActivity.Activity;
		Else
			LineActivity = LineProduct;
		EndIf;
		
		SelectionProduct = SelectionActivity.Select();
		While SelectionProduct.Next() Do
			
			If ShowComponents And ValueIsFilled(SelectionProduct.Product) Then
				NewRow = LineActivity.Rows.Add();
				NewRow.Product = SelectionProduct.Product;
				NewRow.Characteristic = SelectionProduct.Characteristic;
				NewRow.BOMLevel = 1;
				NewRow.Quantity = SelectionProduct.Quantity;
				NewRow.MeasurementUnit = SelectionProduct.MeasurementUnit;
				NewRow.BillOfMaterials = SelectionProduct.Specification;
				NewRow.Activity = SelectionProduct.Activity;
				NewRow.BOMExplosion = SelectionProduct.Product;
			Else
				NewRow = LineActivity;
			EndIf;
			
			If ValueIsFilled(SelectionProduct.Specification) Then
				AddlParameters.Insert("BillOfMaterials", SelectionProduct.Specification);
				FillInTreeLevel(NewRow, 2, MaxNumberOfBOMLevels, AddlParameters);
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Result = New Structure("Tree", Tree);
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure CheckLooping(BOMRef, Cancel) Export
	
	NextLevelBOMArray = New Array();
	LoopBOM = Undefined;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	BillsOfMaterialsContent.Ref AS BOM,
	|	BillsOfMaterialsContent.Specification AS ChildBOM
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|WHERE
	|	BillsOfMaterialsContent.Ref IN(&BOMs)
	|	AND BillsOfMaterialsContent.ManufacturedInProcess
	|	AND BillsOfMaterialsContent.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	Query.SetParameter("BOMs", BOMRef);
	Selection = Query.Execute().Select();
	
	PathsInGraph = New Map;
	
	While Selection.Count() > 0 Do
		
		PathsInGraphNew = New Map;
		
		While Selection.Next() Do
			
			If PathsInGraph[Selection.BOM] = Undefined Then
				MapValueArray = New Array;
			ElsIf PathsInGraph[Selection.BOM].Find(Selection.BOM) = Undefined Then
				MapValueArray = New Array(New FixedArray(PathsInGraph[Selection.BOM]));
			Else
				MaxIndex = PathsInGraph[Selection.BOM].UBound();
				Index = ?(MaxIndex > 0, MaxIndex - 1, 0);
				LoopBOM = PathsInGraph[Selection.BOM].Get(Index);
				NextLevelBOMArray.Clear();
				Break;
			EndIf;
			
			MapValueArray.Insert(0, Selection.BOM);
			PathsInGraphNew.Insert(Selection.ChildBOM, MapValueArray);
			NextLevelBOMArray.Add(Selection.ChildBOM);
			
		EndDo;
		
		Query.SetParameter("BOMs", NextLevelBOMArray);
		Selection = Query.Execute().Select();
		NextLevelBOMArray.Clear();
		
		PathsInGraph = PathsInGraphNew;
		
	EndDo;
	
	If ValueIsFilled(LoopBOM) Then
		ErrorText = NStr("en = 'Using the bill of materials ""%1"" leads to looping.'; ru = '?????????????????????????? ???????????????????????? ""%1"" ?????????? ?? ????????????????????????.';pl = 'U??ycie specyfikacji materia??owych ""%1"" prowadzi do zap??tlenia.';es_ES = 'Utilizar la lista de materiales ""%1"" provoca un bucle.';es_CO = 'Utilizar la lista de materiales ""%1"" provoca un bucle.';tr = '""%1"" ??r??n re??etesini kullanmak d??ng??ye neden oluyor.';it = 'L''utilizzo della distinta base ""%1"" porta a un ciclo.';de = 'Verwenden der St??ckliste ""%1"" f??hrt zu Umschlingung.'");
		ErrorText = StrTemplate(ErrorText, LoopBOM);
		CommonClientServer.MessageToUser(ErrorText,,,, Cancel);
	EndIf;
	
EndProcedure

// Get BOM components, including nested levels.
//
Function GetBOMComponentsIncludingNestedLevels(TableProduction) Export
	
	MaxNumberOfBOMLevels = 1 + Constants.MaxNumberOfBOMLevels.Get();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.MeasurementUnit AS MeasurementUnit
	|INTO TT_Level0
	|FROM
	|	&TableProduction AS TableProduction
	|
	|INDEX BY
	|	Specification";
	
	QueryTextFragment1 = "";
	QueryTextFragment2 = DriveClientServer.GetQueryDelimeter();
	
	For i = 1 To MaxNumberOfBOMLevels Do
		
		Text1 = DriveClientServer.GetQueryDelimeter() + "
			|SELECT
			|	TT_Level.LineNumber AS LineNumber,
			|	TableMaterials.Products AS Products,
			|	CASE
			|		WHEN &UseCharacteristics
			|			THEN TableMaterials.Characteristic
			|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
			|	END AS Characteristic,
			|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * CASE
			|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
			|				THEN ISNULL(UOM.Factor, 1) * TT_Level.Quantity
			|			ELSE CASE
			|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) = ISNULL(UOM.Factor, 1) * TT_Level.Quantity / TableMaterials.Ref.Quantity
			|						THEN ISNULL(UOM.Factor, 1) * TT_Level.Quantity
			|					WHEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) > ISNULL(UOM.Factor, 1) * TT_Level.Quantity / TableMaterials.Ref.Quantity
			|						THEN (CAST(ISNULL(UOM.Factor, 1) * TT_Level.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) * TableMaterials.Ref.Quantity
			|					ELSE ((CAST(ISNULL(UOM.Factor, 1) * TT_Level.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) + 1) * TableMaterials.Ref.Quantity
			|				END
			|		END) AS Quantity,
			|	TableMaterials.Specification AS Specification,
			|	TableMaterials.MeasurementUnit AS MeasurementUnit
			|INTO %1
			|FROM
			|	%2 AS TT_Level
			|		INNER JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
			|		ON TT_Level.Specification = TableMaterials.Ref
			|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
			|		LEFT JOIN Catalog.UOM AS UOM
			|		ON TT_Level.MeasurementUnit = UOM.Ref
			|
			|GROUP BY
			|	TT_Level.LineNumber,
			|	TableMaterials.Specification,
			|	TableMaterials.Products,
			|	TableMaterials.Characteristic,
			|	TableMaterials.MeasurementUnit
			|
			|INDEX BY
			|	Specification";
		
		QueryTextFragment1 = QueryTextFragment1 + StrTemplate(Text1, "TT_Level" + String(i), "TT_Level" + String(i-1));
		
		Text2 = ?(i = 1, "", DriveClientServer.GetQueryUnion()) + "
			|SELECT
			|	TT_Level.LineNumber AS LineNumber,
			|	TT_Level.Products AS Products,
			|	TT_Level.Characteristic AS Characteristic,
			|	TT_Level.Quantity AS Quantity,
			|	TT_Level.MeasurementUnit AS MeasurementUnit
			|%2
			|FROM
			|	%1 AS TT_Level
			|WHERE
			|	%3";
		
		Text2 = StrTemplate(Text2,
			"TT_Level" + String(i),
			?(i = 1, "INTO TT_Components", ""),
			?(i = MaxNumberOfBOMLevels, "TRUE", "TT_Level.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)"));
		QueryTextFragment2 = QueryTextFragment2 + Text2;
		
	EndDo;
	
	Query.Text = Query.Text + QueryTextFragment1 + QueryTextFragment2 + DriveClientServer.GetQueryDelimeter() + "
		|SELECT
		|	MIN(TT_Components.LineNumber) AS LineNumber,
		|	TT_Components.Products AS Products,
		|	TT_Components.Characteristic AS Characteristic,
		|	SUM(TT_Components.Quantity) AS Quantity,
		|	TT_Components.MeasurementUnit AS MeasurementUnit
		|FROM
		|	TT_Components AS TT_Components
		|
		|GROUP BY
		|	TT_Components.Products,
		|	TT_Components.Characteristic,
		|	TT_Components.MeasurementUnit
		|
		|ORDER BY
		|	LineNumber";
	
	Query.SetParameter("TableProduction", TableProduction);
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#Region EventsHandlers

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		
		If ValueIsFilled(Parameters.Filter.Owner) Then
			
			OwnerType = Parameters.Filter.Owner.ProductsType;
			
			If (OwnerType = Enums.ProductsTypes.Service
				OR (NOT Constants.UseProductionSubsystem.Get() AND OwnerType = Enums.ProductsTypes.InventoryItem)
				OR (NOT Constants.UseWorkOrders.Get() AND OwnerType = Enums.ProductsTypes.Work)) Then
			
				Message = New UserMessage();
				LabelText = NStr("en = 'BOM is not specified for products of the %EtcProducts% type.'; ru = '?????? ???????????????????????? ???????? %EtcProducts% ???????????????????????? ???? ??????????????????????!';pl = 'Specyfikacja materia??owa nie jest podana dla %EtcProducts% tego typu produkt??w.';es_ES = 'BOM no est?? especificado para los productos del tipo %EtcProducts%.';es_CO = 'BOM no est?? especificado para los productos del tipo %EtcProducts%.';tr = '%EtcProducts% t??r??ndeki ??r??nler i??in ??r??n re??etesi belirtilmedi.';it = 'La Distinta Base non ?? specificata per gli articoli del tipo %EtcProducts% .';de = 'Die St??ckliste ist f??r Produkte der Art %EtcProducts%  nicht angegeben.'");
				LabelText = StrReplace(LabelText, "%EtcProducts%", OwnerType);
				Message.Text = LabelText;
				Message.Message();
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Parameters.Property("OperationKind") And ValueIsFilled(Parameters.OperationKind) Then
		
		OperKinds = New Array;
		OperKinds.Add(BOMOperationKind(Parameters.OperationKind));
		OperKinds.Add(Enums.OperationTypesProductionOrder.AssemblyDisassembly);
		
		Parameters.Filter.Insert("OperationKind", New FixedArray(OperKinds));
		
	EndIf;
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.BillsOfMaterials);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

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
	AttributesToLock.Add("Owner");
	AttributesToLock.Add("ProductCharacteristic");
	AttributesToLock.Add("UseRouting");
	AttributesToLock.Add("NormalSpoilage");
	AttributesToLock.Add("Quantity");
	AttributesToLock.Add("Operations; OperationsFillInWithTemplate");
	AttributesToLock.Add("Content; ContentDataImportFromExternalSources");
	AttributesToLock.Add("ByProducts");
	AttributesToLock.Add("Status, SetInterval");
	AttributesToLock.Add("ValidityStartDate");
	AttributesToLock.Add("ValidityEndDate");
	AttributesToLock.Add("OperationKind");
	AttributesToLock.Add("BillNumber");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#Region CloneProductRelatedData

Procedure MakeRelatedBillsOfMaterials(ProductReceiver, ProductSource) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	BillsOfMaterials.Ref AS BillOfMaterials
		|FROM
		|	Catalog.BillsOfMaterials AS BillsOfMaterials
		|WHERE
		|	BillsOfMaterials.Owner = &ProductSource";
	
	Query.SetParameter("ProductSource", ProductSource);
	
	QueryResult = Query.Execute();
	
	SelectionBills = QueryResult.Select();
	
	While SelectionBills.Next() Do
		BillOfMaterialsReceiver = SelectionBills.BillOfMaterials.Copy();
		BillOfMaterialsReceiver.Owner = ProductReceiver;
		BillOfMaterialsReceiver.Write();
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function BOMOperationKind(OperationKind) Export
	
	If TypeOf(OperationKind) = Type("EnumRef.OperationTypesProductionOrder") Then
		
		Return OperationKind;
		
	ElsIf OperationKind = Enums.OperationTypesKitOrder.Assembly
		Or OperationKind = Enums.OperationTypesProduction.Assembly Then
		
		Return Enums.OperationTypesProductionOrder.Assembly;
		
	ElsIf OperationKind = Enums.OperationTypesKitOrder.Disassembly
		Or OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		Return Enums.OperationTypesProductionOrder.Disassembly;
		
	ElsIf OperationKind = Enums.OperationTypesProduction.ConvertFromWIP Then
		
		Return Enums.OperationTypesProductionOrder.Production;
		
	Else
		
		Return OperationKind;
		
	EndIf;
	
EndFunction

Function IsBillsWithCharacteristic(ProductCharacteristic, Query, QueryResult)
	
	Result = False;
	
	Query.SetParameter("NotCheckCharacteristic", False);
	Query.SetParameter("ProductCharacteristic", ProductCharacteristic);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		Result = True;
		Break;
	EndDo;
	
	Return Result;
	
EndFunction

Function GetQueryTextDefaultBOMWithOperationKind()

	Return 
	"SELECT DISTINCT
	|	BillsOfMaterials.Ref AS BOM,
	|	BillsOfMaterials.Status AS BOMStatus,
	|	BillsOfMaterials.Owner AS ProductOwner,
	|	Products.Specification AS MainBOM,
	|	BillsOfMaterials.OperationKind AS OperationKind
	|INTO ActiveBOMs
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		INNER JOIN Catalog.Products AS Products
	|		ON BillsOfMaterials.Owner = Products.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsByProducts.Ref
	|WHERE
	|	BillsOfMaterials.Status = &StatusActive
	|	AND BillsOfMaterials.ValidityStartDate <= &ValidDate
	|	AND BillsOfMaterials.ValidityEndDate >= &ValidDate
	|	AND Products.Ref = &ProductOwner
	|	AND (BillsOfMaterials.ProductCharacteristic = &ProductCharacteristic
	|			OR &NotCheckCharacteristic)
	|	AND (BillsOfMaterialsByProducts.Product IS NULL
	|			OR NOT &ExcludeByProducts)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	BillsOfMaterials.Ref,
	|	BillsOfMaterials.Status,
	|	BillsOfMaterials.Owner,
	|	Products.Specification,
	|	BillsOfMaterials.OperationKind
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		INNER JOIN Catalog.Products AS Products
	|		ON BillsOfMaterials.Owner = Products.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsByProducts.Ref
	|WHERE
	|	BillsOfMaterials.Status = &StatusActive
	|	AND BillsOfMaterials.ValidityStartDate = &EmptyDate
	|	AND BillsOfMaterials.ValidityEndDate >= &ValidDate
	|	AND Products.Ref = &ProductOwner
	|	AND (BillsOfMaterials.ProductCharacteristic = &ProductCharacteristic
	|			OR &NotCheckCharacteristic)
	|	AND (BillsOfMaterialsByProducts.Product IS NULL
	|			OR NOT &ExcludeByProducts)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	BillsOfMaterials.Ref,
	|	BillsOfMaterials.Status,
	|	BillsOfMaterials.Owner,
	|	Products.Specification,
	|	BillsOfMaterials.OperationKind
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		INNER JOIN Catalog.Products AS Products
	|		ON BillsOfMaterials.Owner = Products.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsByProducts.Ref
	|WHERE
	|	BillsOfMaterials.Status = &StatusActive
	|	AND BillsOfMaterials.ValidityStartDate <= &ValidDate
	|	AND BillsOfMaterials.ValidityEndDate = &EmptyDate
	|	AND Products.Ref = &ProductOwner
	|	AND (BillsOfMaterials.ProductCharacteristic = &ProductCharacteristic
	|			OR &NotCheckCharacteristic)
	|	AND (BillsOfMaterialsByProducts.Product IS NULL
	|			OR NOT &ExcludeByProducts)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	BillsOfMaterials.Ref,
	|	BillsOfMaterials.Status,
	|	BillsOfMaterials.Owner,
	|	Products.Specification,
	|	BillsOfMaterials.OperationKind
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		INNER JOIN Catalog.Products AS Products
	|		ON BillsOfMaterials.Owner = Products.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsByProducts.Ref
	|WHERE
	|	BillsOfMaterials.Status = &StatusActive
	|	AND BillsOfMaterials.ValidityStartDate = &EmptyDate
	|	AND BillsOfMaterials.ValidityEndDate = &EmptyDate
	|	AND Products.Ref = &ProductOwner
	|	AND (BillsOfMaterials.ProductCharacteristic = &ProductCharacteristic
	|			OR &NotCheckCharacteristic)
	|	AND (BillsOfMaterialsByProducts.Product IS NULL
	|			OR NOT &ExcludeByProducts)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ActiveBOMs.BOM AS BOM,
	|	ActiveBOMs.BOMStatus AS BOMStatus,
	|	ActiveBOMs.ProductOwner AS ProductOwner,
	|	ActiveBOMs.MainBOM AS MainBOM,
	|	ActiveBOMs.OperationKind AS OperationKind
	|FROM
	|	ActiveBOMs AS ActiveBOMs
	|WHERE
	|	ActiveBOMs.OperationKind IN (&OperationTypesOrder)";

EndFunction // GetQueryTextDefaultBOMWithOperationKind()

Function GetQueryTextDefaultBOM()

	Return 
	"SELECT DISTINCT
	|	BillsOfMaterials.Ref AS BOM,
	|	BillsOfMaterials.Status AS BOMStatus,
	|	BillsOfMaterials.Owner AS ProductOwner,
	|	Products.Specification AS MainBOM
	|INTO ActiveBOMs
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		INNER JOIN Catalog.Products AS Products
	|		ON BillsOfMaterials.Owner = Products.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsByProducts.Ref
	|WHERE
	|	BillsOfMaterials.Status = &StatusActive
	|	AND BillsOfMaterials.ValidityStartDate <= &ValidDate
	|	AND BillsOfMaterials.ValidityEndDate >= &ValidDate
	|	AND Products.Ref = &ProductOwner
	|	AND (BillsOfMaterials.ProductCharacteristic = &ProductCharacteristic
	|			OR &NotCheckCharacteristic)
	|	AND (BillsOfMaterialsByProducts.Product IS NULL
	|			OR NOT &ExcludeByProducts)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	BillsOfMaterials.Ref,
	|	BillsOfMaterials.Status,
	|	BillsOfMaterials.Owner,
	|	Products.Specification
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		INNER JOIN Catalog.Products AS Products
	|		ON BillsOfMaterials.Owner = Products.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsByProducts.Ref
	|WHERE
	|	BillsOfMaterials.Status = &StatusActive
	|	AND BillsOfMaterials.ValidityStartDate = &EmptyDate
	|	AND BillsOfMaterials.ValidityEndDate >= &ValidDate
	|	AND Products.Ref = &ProductOwner
	|	AND (BillsOfMaterials.ProductCharacteristic = &ProductCharacteristic
	|			OR &NotCheckCharacteristic)
	|	AND (BillsOfMaterialsByProducts.Product IS NULL
	|			OR NOT &ExcludeByProducts)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	BillsOfMaterials.Ref,
	|	BillsOfMaterials.Status,
	|	BillsOfMaterials.Owner,
	|	Products.Specification
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		INNER JOIN Catalog.Products AS Products
	|		ON BillsOfMaterials.Owner = Products.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsByProducts.Ref
	|WHERE
	|	BillsOfMaterials.Status = &StatusActive
	|	AND BillsOfMaterials.ValidityStartDate <= &ValidDate
	|	AND BillsOfMaterials.ValidityEndDate = &EmptyDate
	|	AND Products.Ref = &ProductOwner
	|	AND (BillsOfMaterials.ProductCharacteristic = &ProductCharacteristic
	|			OR &NotCheckCharacteristic)
	|	AND (BillsOfMaterialsByProducts.Product IS NULL
	|			OR NOT &ExcludeByProducts)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	BillsOfMaterials.Ref,
	|	BillsOfMaterials.Status,
	|	BillsOfMaterials.Owner,
	|	Products.Specification
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		INNER JOIN Catalog.Products AS Products
	|		ON BillsOfMaterials.Owner = Products.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsByProducts.Ref
	|WHERE
	|	BillsOfMaterials.Status = &StatusActive
	|	AND BillsOfMaterials.ValidityStartDate = &EmptyDate
	|	AND BillsOfMaterials.ValidityEndDate = &EmptyDate
	|	AND Products.Ref = &ProductOwner
	|	AND (BillsOfMaterials.ProductCharacteristic = &ProductCharacteristic
	|			OR &NotCheckCharacteristic)
	|	AND (BillsOfMaterialsByProducts.Product IS NULL
	|			OR NOT &ExcludeByProducts)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ActiveBOMs.BOM AS BOM,
	|	ActiveBOMs.BOMStatus AS BOMStatus,
	|	ActiveBOMs.ProductOwner AS ProductOwner,
	|	ActiveBOMs.MainBOM AS MainBOM
	|FROM
	|	ActiveBOMs AS ActiveBOMs";

EndFunction // GetQueryTextDefaultBOM()

Procedure FillInTreeLevel(PrevLevelRow, Val Level, Val MaxNumberOfBOMLevels, AddlParameters)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	BillsOfMaterials.Ref AS Ref,
	|	CASE
	|		WHEN BillsOfMaterials.Quantity = 0
	|			THEN 1
	|		ELSE BillsOfMaterials.Quantity
	|	END AS Quantity
	|INTO BillsOfMaterialsTable
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|WHERE
	|	BillsOfMaterials.Ref = &BOM
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BillsOfMaterialsContent.Products AS Product,
	|	BillsOfMaterialsContent.Characteristic AS Characteristic,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Quantity * ISNULL(CatalogUOM.Factor, 1) * CASE
	|		WHEN BillsOfMaterialsContent.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|			THEN CAST(&Quantity / BillsOfMaterials.Quantity AS NUMBER(15, 4))
	|		WHEN BillsOfMaterials.Quantity > 1
	|			THEN CASE
	|					WHEN (CAST(&Quantity / BillsOfMaterials.Quantity AS NUMBER(15, 0))) = &Quantity / BillsOfMaterials.Quantity
	|						THEN &Quantity / BillsOfMaterials.Quantity
	|					ELSE (CAST(&Quantity / BillsOfMaterials.Quantity - 0.5 AS NUMBER(15, 0))) + 1
	|				END
	|		ELSE CAST(&Quantity / BillsOfMaterials.Quantity AS NUMBER(15, 4))
	|	END AS Quantity,
	|	ISNULL(BillsOfMaterialsOperations.Quantity, 0) * CASE
	|		WHEN BillsOfMaterialsOperations.CalculationMethod = VALUE(Enum.BOMOperationCalculationMethod.Fixed)
	|			THEN 1
	|		WHEN BillsOfMaterialsOperations.CalculationMethod = VALUE(Enum.BOMOperationCalculationMethod.Proportional)
	|			THEN CAST(&Quantity / BillsOfMaterials.Quantity AS NUMBER(15, 4))
	|		WHEN BillsOfMaterials.Quantity > 1
	|			THEN CASE
	|					WHEN (CAST(&Quantity / BillsOfMaterials.Quantity AS NUMBER(15, 0))) = &Quantity / BillsOfMaterials.Quantity
	|						THEN &Quantity / BillsOfMaterials.Quantity
	|					ELSE (CAST(&Quantity / BillsOfMaterials.Quantity - 0.5 AS NUMBER(15, 0))) + 1
	|				END
	|		ELSE CAST(&Quantity / BillsOfMaterials.Quantity AS NUMBER(15, 4))
	|	END AS ActivityQuantity,
	|	BillsOfMaterialsContent.Specification AS BillOfMaterials,
	|	&Level AS BOMLevel,
	|	BillsOfMaterialsContent.Activity AS Activity,
	|	BillsOfMaterialsContent.ActivityConnectionKey AS ConnectionKey
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		INNER JOIN BillsOfMaterialsTable AS BillsOfMaterials
	|		ON BillsOfMaterialsContent.Ref = BillsOfMaterials.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON BillsOfMaterialsContent.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
	|		ON BillsOfMaterialsContent.Activity = BillsOfMaterialsOperations.Activity
	|			AND BillsOfMaterialsContent.Ref = BillsOfMaterialsOperations.Ref
	|			AND BillsOfMaterialsContent.ActivityConnectionKey = BillsOfMaterialsOperations.ConnectionKey
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON BillsOfMaterialsContent.MeasurementUnit = CatalogUOM.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	BillsOfMaterialsOperations.Quantity * CASE
	|		WHEN BillsOfMaterialsOperations.CalculationMethod = VALUE(Enum.BOMOperationCalculationMethod.Fixed)
	|			THEN 1
	|		WHEN BillsOfMaterialsOperations.CalculationMethod = VALUE(Enum.BOMOperationCalculationMethod.Proportional)
	|			THEN CAST(&Quantity / BillsOfMaterials.Quantity AS NUMBER(15, 4))
	|		WHEN BillsOfMaterials.Quantity > 1
	|			THEN CASE
	|					WHEN (CAST(&Quantity / BillsOfMaterials.Quantity AS NUMBER(15, 0))) = &Quantity / BillsOfMaterials.Quantity
	|						THEN &Quantity / BillsOfMaterials.Quantity
	|					ELSE (CAST(&Quantity / BillsOfMaterials.Quantity - 0.5 AS NUMBER(15, 0))) + 1
	|				END
	|		ELSE CAST(&Quantity / BillsOfMaterials.Quantity AS NUMBER(15, 4))
	|	END,
	|	UNDEFINED,
	|	&Level,
	|	BillsOfMaterialsOperations.Activity,
	|	BillsOfMaterialsOperations.ConnectionKey
	|FROM
	|	BillsOfMaterialsTable AS BillsOfMaterials
	|		INNER JOIN Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsOperations.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON (BillsOfMaterialsOperations.Activity = BillsOfMaterialsContent.Activity)
	|			AND (BillsOfMaterialsOperations.Ref = BillsOfMaterialsContent.Ref)
	|WHERE
	|	BillsOfMaterialsContent.Activity IS NULL
	|TOTALS
	|	MAX(ActivityQuantity),
	|	MAX(BOMLevel),
	|	MAX(Activity)
	|BY
	|	ConnectionKey";
	
	Query.SetParameter("BOM", ?(ValueIsFilled(PrevLevelRow.BillOfMaterials), PrevLevelRow.BillOfMaterials, AddlParameters.BillOfMaterials));
	Query.SetParameter("Quantity", PrevLevelRow.Quantity);
	Query.SetParameter("Level", Level);
	
	Pcs = Catalogs.UOMClassifier.pcs;
	
	SelectionActivity = Query.Execute().Select(QueryResultIteration.ByGroups);
	While SelectionActivity.Next() Do
		
		If AddlParameters.ShowOperations Then
			LineActivity = PrevLevelRow.Rows.Add();
			LineActivity.BOMLevel = SelectionActivity.BOMLevel;
			LineActivity.Activity = SelectionActivity.Activity;
			LineActivity.Quantity = SelectionActivity.ActivityQuantity;
			LineActivity.MeasurementUnit = Pcs;
			LineActivity.BOMExplosion = SelectionActivity.Activity;
		Else
			LineActivity = PrevLevelRow;
		EndIf;
		
		SelectionProduct = SelectionActivity.Select();
		While SelectionProduct.Next() Do
			
			If AddlParameters.ShowComponents And ValueIsFilled(SelectionProduct.Product) Then
				NewRow = LineActivity.Rows.Add();
				FillPropertyValues(NewRow, SelectionProduct);
				NewRow.BOMExplosion = SelectionProduct.Product;
			Else
				NewRow = LineActivity;
			EndIf;
			
			AddlParameters.Insert("BillOfMaterials", SelectionProduct.BillOfMaterials);
			
			If ValueIsFilled(SelectionProduct.BillOfMaterials) And Level < MaxNumberOfBOMLevels Then
				FillInTreeLevel(NewRow, Level+1, MaxNumberOfBOMLevels, AddlParameters);
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure UpToRoot(BOMRef, Val CurLevel, MaxLevel, Val MaxNumberOfBOMLevels)
	
	If Not ValueIsFilled(BOMRef) Then
		Return;
	EndIf;
	
	If CurLevel > MaxLevel Then
		MaxLevel = CurLevel;
	EndIf;
	
	If MaxLevel > MaxNumberOfBOMLevels Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("BOMRef", BOMRef);
	Query.Text =
	"SELECT DISTINCT
	|	BillsOfMaterials.Ref AS Ref
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsContent.Ref
	|WHERE
	|	BillsOfMaterialsContent.Specification = &BOMRef
	|	AND BillsOfMaterialsContent.ManufacturedInProcess
	|	AND BillsOfMaterials.Status = VALUE(Enum.BOMStatuses.Active)
	|	AND NOT BillsOfMaterials.DeletionMark";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		UpToRoot(Selection.Ref, CurLevel + 1, MaxLevel, MaxNumberOfBOMLevels);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
