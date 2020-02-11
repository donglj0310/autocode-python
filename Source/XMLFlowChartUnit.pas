unit XMLFlowChartUnit;

interface

//{$DEFINE  _DEBUG}

uses
     //�Ա�ģ��
     SysRecords,
     SysConsts,
     SysUnits,
     SysVars,
     //�������ؼ�
     GDIPAPI,GDIPOBJ,
     //ϵͳ�Դ�
     XMLDoc,XMLIntf,
     Forms,Math,Graphics,SysUtils,Dialogs,windows,Classes,ExtCtrls;


//==============================��������ͼ����====================================================//
//VST : ��ǰVirtualStringTree
//Node : ��ǰ�ڵ�
//Image : �����ͼƬ
//Config : ������Ϣ
function  DrawXmlToFlowChart(Node:IXMLNode;Image:TImage;Config:TWWConfig):Integer;



implementation


//���õ�ǰ�ڵ�������ӽڵ��X,Y,W,H,EΪ-1;
procedure SetChildNull(Node:IXMLNode);
var
     I         : Integer;
begin
     Node.Attributes['X']     := -1;
     Node.Attributes['Y']     := -1;
     Node.Attributes['W']     := -1;
     Node.Attributes['H']     := -1;
     Node.Attributes['E']     := -1;
     for I:=0 to Node.ChildNodes.Count-1 do begin
          SetChildNull(Node.ChildNodes[I]);
     end;
end;

function  DrawXmlToFlowChart(Node:IXMLNode;Image:TImage;Config:TWWConfig):Integer;
type
     TNodeWHE = record
          W,H,E     : Integer;
     end;
var
     I,J,K     : Integer;
     iLevel    : Integer;
     iRight    : Single;      //���ڼ�¼Case����һ�ӿ���ұ߽�ֵ
     xnNode    : IXMLNode;    //��ʱ�ڵ�
     xnChild   : IXMLNode;    //�ӽڵ�
     xnExtra   : IXMLNode;    //�����ӽڵ�
     xnLast    : IXMLNode;    //��ǰ����XML�ڵ�
     xnNext    : IXMLNode;
     
     iMaxLevel : Integer;     //������
     iMinLevel : Integer;     //��ǳ���
     oCur      : IXMLNode;
     oFor      : IXMLNode;     //�����ж�FOR��E�Ŀ�
     oPar      : IXMLNode;
     oChild    : IXMLNode;
     oExtra    : IXMLNode;
     sText     : string;      //���ڱ���ģ���TEXT
     //
     BW,BH     : Single;
     SH,SV     : Single;
     iMaxE     : Integer;
     iMaxH     : Integer;
     iPos      : Integer;
     X,Y,W,H,E : Single;
     iImageW   : Integer;     //����ͼͼƬ����
     iImageH   : Integer;     //����ͼͼƬ�߶�
     //
     iTop      : Single;
     sInit     : String;
     sJudge    : String;
     sNext     : String;

     //
     iTmp      : Single;
     bTmp      : Boolean;
     sTmp      : String;

     //
     iCode     : Integer;
     slTmp     : TStringList;

     //
     oPen      : TGPPen;
     oGraph    : TGPGraphics;
     oBrush    : TGPSolidBrush;
     oFontBrh  : TGPSolidBrush;
     oFont     : TGPFont;
     oFontB    : TGPFont;
     oFormat   : TGPStringFormat;
     oPath     : TGPGraphicsPath;

     //
     fCurScale : Double;      //��ǰ�������Ų���
{$IFDEF _DEBUG}
     xDebug    : TXMLDocument;
     xNode     : IXMLNode;
{$ENDIF}

const
     iDeltaX = 2;
     iDeltaY = 7;

     //
     procedure DrawPoints(Pts:array of Single);overload;
     var
          I,iCount  : Integer;
          rPath     : TGPGraphicsPath;
          rGPPts    : array[0..99] of TGPPointF;
     begin

          //�õ�����
          iCount    := Length(Pts) div 2;
          //���õ�����
          for I:=0 to iCount-1 do begin
               rGPPts[I].X    := Pts[I*2];
               rGPPts[I].Y    := Pts[I*2+1];
          end;
          //����·��
          rPath     := TGPGraphicsPath.Create;
          rPath.AddLines(PGPPointF(@rGPPts[0]),iCount);
          //����
          oGraph.DrawPath(oPen,rPath);

          //�ͷ��˳�
          rPath.destroy;

          //---------------
          Image.Canvas.MoveTo(Round(Pts[0]),Round(Pts[1]));
          //�õ�����
          iCount    := Length(Pts) div 2;
          //���õ�����
          for I:=1 to iCount-1 do begin
               Image.Canvas.LineTo(Round(Pts[I*2]),Round(Pts[I*2+1]));
          end;


     end;

     //�����������,��������
     procedure DrawPoints(Pts:array of Single;Color:TColor);overload;
     var
          I,iCount  : Integer;
          rPath     : TGPGraphicsPath;
          rGPPts    : array[0..99] of TGPPointF;
          rRegion   : TGPRegion;
          oIFBrush  : TGPSolidBrush;
     begin

          //�õ�����
          iCount    := Length(Pts) div 2;
          //���õ�����
          for I:=0 to iCount-1 do begin
               rGPPts[I].X    := Pts[I*2];
               rGPPts[I].Y    := Pts[I*2+1];
          end;
          //����·��
          rPath     := TGPGraphicsPath.Create;
          rPath.AddLines(PGPPointF(@rGPPts[0]),iCount);

          //<�����ҪͿɫ,��Ϳɫ
          // Construct a region based on the path.
          rRegion   := TGPRegion.Create(rPath);
          //
          oIFBrush  := TGPSolidBrush.Create(ColorToGP(Color));
          //
          oGraph.FillRegion(oIFBrush,rRegion);
          //
          rRegion.Destroy;
          oIFBrush.Destroy;
          //>

          //����
          oGraph.DrawPath(oPen,rPath);

          //�ͷ��˳�
          rPath.destroy;

     end; //end of DrawPoints

     //�������ϻ����ϼ�ͷ(iX,iYΪ���ĵ�����)
     procedure DrawArrow(iX,iY:Single;bDown:Boolean);
     begin
          if bDown then begin
               iY   := iY+iDeltaY*Config.Scale/2;
               DrawPoints([iX,iY,  iX+iDeltaX*Config.Scale,iY-iDeltaY*Config.Scale,
                         iX-iDeltaX*Config.Scale,iY-iDeltaY*Config.Scale,  iX,iY]);
          end else begin
               iY   := iY-iDeltaY*Config.Scale/2;
               DrawPoints([iX,iY,  iX+iDeltaX*Config.Scale,iY+iDeltaY*Config.Scale,
                         iX-iDeltaX*Config.Scale,iY+iDeltaY*Config.Scale,  iX,iY]);
          end;
     end; //end of DrawArrow

     //�������ο�,iX,iYΪ�϶�������
     procedure DrawDiamond(iX,iY:Single;Text:String);
     var
          rGPPts    : array[0..3] of TGPPointF;
          rPath     : TGPGraphicsPath;
          rRegion   : TGPRegion;
          oIFBrush  : TGPSolidBrush;
     begin
          rGPPts[0].X    := iX;
          rGPPts[0].Y    := iY;
          rGPPts[1].X    := iX-BW;
          rGPPts[1].Y    := iY+BH;
          rGPPts[2].X    := iX;
          rGPPts[2].Y    := iY+BH*2;
          rGPPts[3].X    := iX+BW;
          rGPPts[3].Y    := iY+BH;
          //
          rPath     := TGPGraphicsPath.Create;
          rpath.AddPolygon(PGPPointF(@rGPPts), 4);

          // Construct a region based on the path.
          rRegion   := TGPRegion.Create(rPath);
          //
          oIFBrush  := TGPSolidBrush.Create(ColorToGP(Config.IFColor));
          //��������
          oGraph.FillRegion(oIFBrush,rRegion);
          //�������
          oPen.SetColor(ColorToGP(Config.IFColor));
          oGraph.DrawPath(oPen,rPath);
          oPen.SetColor(ColorToGP(Config.LineColor));
          //д����
          oGraph.DrawString(Text,-1,oFontB,MakeRect(iX-BW,iY,BW*2,BH*2.0),oFormat,oFontBrh);
          DrawPoints([iX,iY,  iX-BW,iY+BH,  iX,iY+BH*2,  iX+BW,iY+BH,  iX,iY]);

          //
          oIFBrush.Free;
          rRegion.Free;
          rPath.Free;
     end;

     //����һ�㷽��(iX,iYΪ�ϱ����ĵ����꣬TextΪ�ı�,CollapedΪ�Ƿ��£���־)
     procedure DrawBlock(iX,iY:Single;Text:String;Collapsed:Boolean);
     begin
          DrawPoints([iX-BW,iY,  iX+BW,iY,  iX+BW,iY+BH,  iX-BW,iY+BH,  iX-BW,iY]);
          oGraph.DrawString(Text,-1,oFont,MakeRect(iX*1.0-BW,iY,BW*2,BH),oFormat,oFontBrh);
          if Collapsed then begin
               //���������
               DrawPoints([iX-BW+5,iY,  iX-BW+5,iY+BH]);
               DrawPoints([iX+BW-5,iY,  iX+BW-5,iY+BH]);
          end;
     end;

     //���ƴ��뷽��(iX,iYΪ�ϱ����ӵ����꣬iW,iHΪ���Ϳ�,TextΪ�ı�)
     procedure DrawCodeBlock(iX,iY,iW,iH:Single;Text:String);
     begin
          oFormat.SetAlignment(StringAlignmentNear);
          DrawPoints([iX-BW,iY,  iX-BW+iW,iY,  iX-BW+iW,iY+iH,  iX-BW,iY+iH,  iX-BW,iY]);
          oGraph.DrawString(Text,-1,oFont,MakeRect(X*1.0-BW+4,Y,iW-4,iH),oFormat,oFontBrh);    //4���ڴ��������������,�Ƚ�����
          oFormat.SetAlignment(StringAlignmentCenter);
     end;

     //������ʼ��־,˫��Բ��+����(iX,iYΪ�ϱ����ĵ����꣬TextΪ�ı�)
     procedure DrawRoundRect(iX,iY:Single;Text:String);
     begin
          iTmp := Round(BW/2);    //���,���ȵ�һ��
          oPath.CloseAllFigures;
          oPath.AddLine(X-iTmp+1,Y,  X+iTmp-1,Y);
          oPath.AddArc(X+iTmp-BH/2,Y,BH,BH,-90,180);
          oPath.AddLine(X-iTmp+1,Y+BH,  X+iTmp-1,Y+BH);
          oPath.AddArc(X-iTmp-BH/2,Y,BH,BH,90,180);
          oGraph.DrawPath(oPen,oPath);
          oGraph.DrawString(Text,-1,oFontB,MakeRect(X-BW,Y,BW*2,BH),oFormat,oFontBrh);
     end;


     //����TRY�ĸ�����״ (iX,iYΪ�ϱ����ĵ����꣬TextΪ�ı�,ModeΪ����,0:TRY,1:EXCEPT/FINALLY,3.END)
     procedure DrawTry(iX,iY:Single;Text:String;Collapsed:Boolean;Mode:Integer);
     begin
          case Mode of
               //Try
               0 : begin
                    DrawPoints([X,Y+BH,  X-BW,Y+BH,  X-BW,Y,  X+BW,Y,  X+BW-BH,Y+BH,  X,Y+BH,  X,Y+BH+SV]);
                    oGraph.DrawString(Text,-1,oFontB,MakeRect(X*1.0-BW,Y,BW*2,BH),oFormat,oFontBrh);
               end;

               //except/finally
               1 : begin
                    //����
                    DrawPoints([X,Y+BH,  X-BW,Y+BH,  X-BW,Y,  X+BW,Y,  X+BW-BH*1/2,Y+BH/2,  X+BW,Y+BH,  X,Y+BH,  X,Y+BH+SV]);
                    oGraph.DrawString(Text,-1,oFontB,MakeRect(X*1.0-BW,Y,BW*2,BH),oFormat,oFontBrh);
                    if Collapsed then begin
                         //��������
                         DrawPoints([X-BW+5,Y,  X-BW+5,Y+BH]);
                    end;
               end;

               //end of try
               2 : begin
                    //����End of Try
                    iTmp := Y+H-BH-SV;
                    DrawPoints([X,iTmp+BH,  X-BW,iTmp+BH,  X-BW,iTmp,  X+BW-BH,iTmp,  X+BW,iTmp+BH,  X,iTmp+BH,  X,iTmp+BH+SV]);
                    oGraph.DrawString(Text,-1,oFontB,MakeRect(X*1.0-BW,iTmp,BW*2,BH),oFormat,oFontBrh);
               end;
          end;
     end;
     
     procedure DrawText(Text:String;X,Y,W,H:Single);
     begin
          oGraph.DrawString(Text,-1,oFontB,MakeRect(X,Y,W,H),oFormat,oFontBrh);
     end;
     procedure GetGPTextWH(Text:string;
               Font:TGPFont;FontFormat:TGPStringFormat;
               FontFamily:TGPFontFamily;
               var Width:Single;var Height:Single);
     var
          oPath   : TGPGraphicsPath;
          oRect   : TGPPointF;
          strFormat    : TGPStringFormat;
          rcBound      : TGPRectF;
     begin
          oPath     := TGPGraphicsPath.Create;
          strFormat := TGPStringFormat.Create();
          oPath.AddString(Text,-1,
                    FontFamily,
                    font.GetStyle(),
                    font.GetSize(),
                    oRect,strFormat);
          oPath.GetBounds(rcBound);

          //
          Width     := rcBound.Width;
          Height    := rcBound.Height;
     end;
     function GetGPTextWidth(Text:string):Single;
     var
          W,H       : Single;
          oFF       : TGPFontFamily;
          oFormat   : TGPStringFormat;
     begin
          oFormat   := TGPStringFormat.Create();
          oFF       := TGPFontFamily.Create;
          oFont.GetFamily(oFF);//oFF       := TGPFontFamily.Create(Config.FontName);

          GetGPTextWH(Text,oFont,oFormat,oFF,W,H);
          Result    := W;
          oFormat.Destroy;
          oFF.Destroy;
     end;
     function GetGPTextHeight(Text:string):Single;
     var
          W,H       : Single;
          oFF       : TGPFontFamily;
          oFormat   : TGPStringFormat;
     begin
          oFormat   := TGPStringFormat.Create();
          oFF       := TGPFontFamily.Create;
          oFont.GetFamily(oFF);//oFF       := TGPFontFamily.Create(Config.FontName);
          GetGPTextWH(Text,oFont,oFormat,oFF,W,H);
          Result    := H;
          oFormat.Destroy;
          oFF.Destroy;
     end;

     procedure SetNodePosition(Node:IXMLNode);
     var
          II,JJ     : Integer;
     begin
          //����ýڵ��£,�򲻱�Ҫ�������ӽڵ��λ��
          if not Node.Attributes['Expanded'] then begin
               Exit;
          end;
          
          //<���ݵ�ǰ�ڵ�����ͼ����ӽڵ�λ��
          case Node.Attributes['Mode'] of

               rtIF : begin
                    //YES��
                    xnChild   := Node.ChildNodes.First;
                    xnChild.Attributes['X']  := Node.Attributes['X'];
                    xnChild.Attributes['Y']  := Node.Attributes['Y']+BH*2+SV;

                    //ELIF / NO��
                    for JJ := 1 to Node.ChildNodes.Count-1 do begin
                         xnExtra   := xnChild.NextSibling;
                         xnExtra.Attributes['X']  := 0+_R(xnChild) + SH + _E(xnExtra) + BW;
                         xnExtra.Attributes['Y']  := _Y(xnChild);
                         //
                         xnChild   := xnExtra;
                    end;
               end; //end mode

               rtFor : begin
                    //�ӿ�
                    xnChild   := Node.ChildNodes.First;
                    xnChild.Attributes['X']  := Node.Attributes['X'];
                    xnChild.Attributes['Y']  := Node.Attributes['Y']+ BH+Sv;
               end; //end mode

               rtWhile : begin
                    //�ӿ�
                    xnChild   := Node.ChildNodes.First;
                    xnChild.Attributes['X']  := Node.Attributes['X'];
                    xnChild.Attributes['Y']  := Node.Attributes['Y']+ BH*2+Sv*2;
               end; //end mode

               rtRepeat : begin
                    //�ӿ�
                    xnChild   := Node.ChildNodes.First;
                    xnChild.Attributes['X']  := Node.Attributes['X'];
                    xnChild.Attributes['Y']  := Node.Attributes['Y']+Sv;
               end; //end mode

               rtCase : begin
                    iRight    := 0;
                    for JJ:=0 to Node.ChildNodes.Count-1 do begin
                         //�õ��ӿ�ڵ�
                         if JJ=0 then begin
                              //�õ��ӿ���Ϣ
                              xnChild   := Node.ChildNodes.First;
                              //
                              xnChild.Attributes['X']  := Node.Attributes['X'];
                              xnChild.Attributes['Y']  := BH*2+SV*2+Node.Attributes['Y'];

                              //�õ���ǰ�ӿ��ұ߽�ֵ,���ڼ�����һ�ӿ��λ��
                              iRight    := StrToFloat(xnChild.Attributes['X'])+xnChild.Attributes['W'] -BW;
                         end else begin
                              //�õ��ӿ���Ϣ
                              xnChild   := xnChild.NextSibling;
                              //
                              xnChild.Attributes['X']  := iRight+SH*2+xnChild.Attributes['E']+BW;
                              xnChild.Attributes['Y']  := BH*2+SV*2+Node.Attributes['Y'];

                              //�õ���ǰ�ӿ��ұ߽�ֵ,���ڼ�����һ�ӿ��λ��
                              iRight    := StrToFloat(xnChild.Attributes['X'])+xnChild.Attributes['W'] -BW;
                         end;
                    end;
               end; //end mode

               rtCase_Item,rtCase_Default : begin
                    iTop := 0;
                    for JJ:=0 to Node.ChildNodes.Count-1 do begin
                         if JJ=0 then begin
                              xnChild   := Node.ChildNodes.First;
                         end else begin
                              xnChild   := xnChild.NextSibling;
                         end;
                         //
                         xnChild.Attributes['X']  := Node.Attributes['X'];
                         xnChild.Attributes['Y']  := Node.Attributes['Y']+iTop;
                         //
                         iTop := iTop+xnChild.Attributes['H'];

                    end;
                    iRight    := 0;
               end; //end mode

               rtTry : begin
                    iTop := 0;
                    for JJ:=0 to Node.ChildNodes.Count-1 do begin
                         if JJ=0 then begin
                              xnChild   := Node.ChildNodes.First;
                              //
                              xnChild.Attributes['X']  := Node.Attributes['X'];
                              xnChild.Attributes['Y']  := Node.Attributes['Y']+BH+SV;
                              iTop := StrToFloat(xnChild.Attributes['Y'])+xnChild.Attributes['H'];
                         end else begin
                              xnChild   := xnChild.NextSibling;
                              //
                              xnChild.Attributes['X']  := Node.Attributes['X'];
                              xnChild.Attributes['Y']  := iTop;
                              //
                              iTop := StrToFloat(xnChild.Attributes['Y'])+xnChild.Attributes['H'];
                         end;
                    end;
               end; //end mode

               rtTry_Except,rtTry_Finally,rtTry_Else : begin
                    iTop := 0;
                    for JJ:=0 to Node.ChildNodes.Count-1 do begin
                         if JJ=0 then begin
                              xnChild   := Node.ChildNodes.First;
                              //
                              xnChild.Attributes['X']  := Node.Attributes['X'];
                              xnChild.Attributes['Y']  := Node.Attributes['Y']+BH+SV;
                              iTop := StrToFloat(xnChild.Attributes['Y'])+xnChild.Attributes['H'];
                         end else begin
                              xnChild   := xnChild.NextSibling;
                              //
                              xnChild.Attributes['X']  := Node.Attributes['X'];
                              xnChild.Attributes['Y']  := iTop;
                              //
                              iTop := StrToFloat(xnChild.Attributes['Y'])+xnChild.Attributes['H'];
                         end;
                    end;
               end; //end mode
          else
               iTop := 0;
               for JJ:=0 to Node.ChildNodes.Count-1 do begin
                    if JJ=0 then begin
                         xnChild   := Node.ChildNodes.First;
                    end else begin
                         xnChild   := xnChild.NextSibling;
                    end;
                    //
                    xnChild.Attributes['X']  := Node.Attributes['X'];
                    xnChild.Attributes['Y']  := Node.Attributes['Y']+iTop;
                    //
                    iTop := iTop+xnChild.Attributes['H'];

               end;
               iRight    := 0;

          end;


          //�ݹ�����ӽڵ���ӽڵ�λ��
          for II:=0 to Node.ChildNodes.Count-1 do begin
               SetNodePosition(Node.ChildNodes[II]);
          end;
     end;
     //
     procedure DrawNodeFlowchart(Node:IXMLNode);
     var
          II,JJ     : Integer;
     begin
          try
               if not Node.HasAttribute('X') then begin
                    ShowMessage('Error not XYWHE! '#13#13+Node.XML);
                    Exit;
               end;
               //�����򵥱����Ա�����д
               X    := Node.Attributes['X'];
               Y    := Node.Attributes['Y'];
               E    := Node.Attributes['E'];
               W    := Node.Attributes['W'];
               H    := Node.Attributes['H'];

               //
               if Node.Attributes['W']=-1 then begin
                    Exit;
               end;

               //<�����ӽڵ���Ϊ0�Ľڵ�ͺ�£�Ľڵ�
               if (Node.ChildNodes.Count=0) then begin
                    //�������ӿ�ڵ�(��������ת����֧)
                    if (_M(Node)=rtBlock_Code) and((Node.Attributes['ShowDetailCode']=1)or(grConfig.ShowDetailCode and (Node.Attributes['ShowDetailCode']<>2))) then begin
                         //�ڵ�(����)
                         DrawCodeBlock(X,Y,W,H-SV,Node.Attributes['Text']);
                         //�½���
                         DrawPoints([X,Y+H-SV,  X,Y+H]);
                         //
                         Exit;
                    end else if not InModes(Node.Attributes['Mode'],[rtCase_Item,rtCase_Default,rtTry_Except,rtTry_Finally]) then begin
                         if InModes(_M(Node),[rtIF_Else,rtIF_Elseif]) then begin

                              //�½���
                              DrawPoints([X,Y,  X,Y+BH+SV]);
                              //
                              Exit;
                         end else begin
                              //�ڵ�(����)
                              DrawBlock(X,Y,GetNodeText(Node),False);
                              //�½���
                              DrawPoints([X,Y+BH,  X,Y+BH+SV]);
                              //
                              Exit;
                         end;
                    end;
               end else if (Node.Attributes['Expanded']=False) then begin
                    //������£�Ľڵ�(��������֧)
                    if not InModes(Node.Attributes['Mode'],[rtCase_Item,rtCase_Default,rtTry_Except,rtTry_Finally]) then begin
                         //��£�ڵ�(����)
                         DrawBlock(X,Y,GetNodeText(Node),False);  //RTtoStr(Node.Attributes['Mode'])
                         //�½���
                         DrawPoints([X,Y+BH,  X,Y+BH+SV]);
                         //
                         Exit;
                    end;
               end;
               //>


               //
               case Node.Attributes['Mode'] of
                    //
                    rtIF : begin
                         //���ο�
                         DrawDiamond(X,Y,Format('%s',[GetNodeText(Node)]));
                         DrawPoints([X,Y+BH*2,  X,Y+BH*2+SV]); //������
                         //���ο�����������
                         xnChild   := Node.ChildNodes[0];
                         if _M(Node.ChildNodes[1]) = rtIF_ElseIf then begin
                              DrawPoints([_X(xnChild)+BW,Y+BH,  _EL(xnChild.NextSibling),Y+BH]);
                         end else begin
                              DrawPoints([_X(xnChild)+BW,Y+BH,  _X(xnChild.NextSibling),Y+BH]);
                         end;

                         //
                         for JJ:=1 to Node.ChildNodes.Count-1 do begin
                              xnChild   := Node.ChildNodes[JJ];
                              if _M(xnChild) = rtIF_ElseIf then begin
                                   //���ο�
                                   DrawDiamond(_X(xnChild),_Y(xnChild)-BH*2-SV,GetNodeText(xnChild));
                                   DrawPoints([_X(xnChild),_Y(xnChild)-SV,_X(xnChild),_Y(xnChild)]); //���ο�������
                                   DrawPoints([_X(xnChild)+BW,_Y(xnChild)-SV-BH,_EL(xnChild.NextSibling),_Y(xnChild)-SV-BH]);  //���ο�����������

                              end else begin
                                   DrawPoints([_L(xnChild),_Y(xnChild)-SV-BH,_X(xnChild),_Y(xnChild)-SV-BH]);  //����ģ�����ο�����������
                                   DrawPoints([_X(xnChild),_Y(xnChild)-SV-BH,_X(xnChild),_Y(xnChild)]); //�����ο�������
                              end;
                                   DrawPoints([_X(xnChild),_B(xnChild),_X(xnChild),_EB(xnChild.ParentNode)]); //ģ��������½���
                         end;

                         //�����ģ���½���
                         DrawPoints([X,Y+H-SV,_X(Node.ChildNodes.Last),Y+H-SV]);
                         //YES����½���
                         DrawPoints([X,_B(Node.ChildNodes.First),  X,Y+H]);

                    end;

                    //
                    rtFOR : begin
                         //FOR��
                         DrawPoints([X-BW,Y,  X+W-BW-Sh-BH,Y,  X+W-BW-Sh,Y+BH/2,  X+W-BW-Sh-BH,Y+BH,  X-BW,Y+BH,  X-BW,Y],Config.IFColor);
                         DrawText(''+GetNodeText(Node),X-BW,Y,W-Sh-BH/2,BH);
                         DrawPoints([X,Y+BH,  X,Y+BH+SV]);
                         //�õ��ӿ�
                         xnChild   := Node.ChildNodes.First;
                         //�˳�ѭ����
                         DrawPoints([X+W-BW-Sh,Y+BH/2,  X+W-BW,Y+BH/2,  X+W-BW,Y+H-SV,  X,Y+H-SV,  X,Y+H]);
                         DrawArrow(X+W-BW,Y+H / 2, True);
                         //����ѭ����
                         DrawPoints([X,Y+H-SV*3,  X,Y+H-SV*2,  X-BW-E,Y+H-SV*2,  X-BW-E,Y+BH/2,  X-BW,Y+BH/2]);
                         DrawArrow(X-BW-E,Y+H / 2, False);
                    end;

                    //
                    rtWhile : begin
                         //���ο�
                         DrawDiamond(X,Y+SV,Format('%s',[GetNodeText(Node)]));
                         DrawPoints([X,Y+BH*2+SV,  X,Y+BH*2+SV*2]);
                         //�õ��ӿ�
                         xnChild   := Node.ChildNodes.First;
                         //�˳�ѭ����
                         DrawPoints([X+BW,Y+BH+SV,  X+W-BW,Y+BH+SV,  X+W-BW,Y+H-SV,  X,Y+H-SV,  X,Y+H]);
                         DrawArrow(X+W-BW,Y+H / 2, True);
                         //����ѭ����
                         DrawPoints([X,StrToFloat(xnChild.Attributes['Y'])+xnChild.Attributes['H'],
                                   X,Y+H-SV*2,  X-BW-E,Y+H-SV*2,  X-BW-E,Y,  X,Y,  X,Y+SV]);
                         DrawArrow(X-BW-E,Y+H / 2, False);
                    end;

                    //
                    rtRepeat : begin
                         //�õ��ӿ�
                         xnChild   := Node.ChildNodes.First;
                         //���ο�
                         DrawDiamond(X,StrToFloat(xnChild.Attributes['Y'])+xnChild.Attributes['H'],
                                   Format('%s',[GetNodeText(Node)]));
                         DrawPoints([X,StrToFloat(xnChild.Attributes['Y'])+xnChild.Attributes['H']+BH*2,
                                   X,StrToFloat(xnChild.Attributes['Y'])+xnChild.Attributes['H']+BH*2+SV]);
                         //�˳�ѭ����
                         DrawPoints([X+BW,Y+H-SV*3-BH,  X+W-BW,Y+H-SV*3-BH,  X+W-BW,Y+H-SV,  X,Y+H-SV,  X,Y+H]);
                         DrawArrow(X+W-BW,Y+H-SV*2-BH/2, True);
                         //����ѭ����
                         DrawPoints([X,Y+H-SV*3,  X,Y+H-SV*2,  X-BW-E,Y+H-SV*2,  X-BW-E,Y,  X,Y,  X,Y+SV]);
                         DrawArrow(X-BW-E,Y+(H-SV*2)/2, False);
                    end;

                    //
                    rtCase : begin
                         //�����ӿ�
                         bTmp := False; //��¼�Ƿ��������ת����һ��֧����

                         //
                         for JJ:=0 to Node.ChildNodes.Count-1 do begin
                              //�õ���Ӧ�ӿ�
                              xnChild   := Node.ChildNodes[JJ];

                              //�õ��ӿ����Ϣ
                              X    := xnChild.Attributes['X'];
                              Y    := xnChild.Attributes['Y'];
                              E    := xnChild.Attributes['E'];
                              W    := xnChild.Attributes['W'];
                              H    := xnChild.Attributes['H'];

                              //���ο�
                              DrawDiamond(X,Y-BH*2-SV*2,xnChild.Attributes['Caption']);
                              //���ο��½���
                              DrawPoints([X,Y-SV*2,  X,Y]);
                              //���ο������������������һ��ITEM����
                              DrawPoints([X-BW,Y-SV*2-BH,  X-BW-E,Y-SV*2-BH]);

                              //�����һ����ת������, ����Ҫ������ת��
                              if bTmp then begin
                                   DrawPoints([X,Y-SV,  X-BW-E,Y-SV]);
                              end;
                              //
                              bTmp := False; //��¼�Ƿ��������ת����һ��֧����

                              //����ǵ�һ��֦, ���������һ�������ߵı����ڲ���
                              if J>0 then begin
                                   DrawPoints([X-BW,Y-BH-SV*2,  X-BW-E,Y-BH-SV*2]);
                              end;
                         
                              //����һ���ڵ����(��),���п�����ת����һ��֧����
                              if JJ<>Node.ChildNodes.Count-1 then begin
                                   //����(ֻ���Ʊ����зֽ粿��)
                                   DrawPoints([X+BW,Y-BH-SV*2,  X+W-BW+SH*2,Y-BH-SV*2]);

                                   if InModes(Config.Language,[loC,loCpp]) then begin
                                        //������һ���ӿ鲻����ת, �����һ����ת����һ��֧����(����λ�ڱ����ڵĲ���)
                                        if Config.Language in [loC,loCpp] then begin
                                             if xnChild.HasChildNodes then begin
                                                  xnChild   := xnChild.ChildNodes.Last;
                                                  if not InModes(xnChild.Attributes['Mode'],[rtJUMP_Break,rtJUMP_Continue,rtJUMP_Exit,rtJUMP_Goto]) then begin
                                                       DrawPoints([X,Y+H,  X+W-BW+SH,Y+H,  X+W-BW+SH,Y-SV,  X+W-BW+SH*2,Y-SV]);
                                                       bTmp := True;
                                                  end;
                                             end else begin
                                                  //�����ǰ��֧û���ӿ�,��ֱ����ת����һ��
                                                  DrawPoints([X,Y,  X+W-BW+SH,Y,  X+W-BW+SH,Y-SV,  X+W-BW+SH*2,Y-SV]);
                                                  bTmp := True;
                                             end;
                                        end;
                                   end;
                              end else begin     //�����һ���ӿ����SWITCH�Ķ��֧��ͳһ������
                                   DrawPoints([X,StrToFloat(Node.Attributes['Y'])+Node.Attributes['H']-SV,
                                             Node.Attributes['X'], StrToFloat(Node.Attributes['Y'])+Node.Attributes['H']-SV,
                                             Node.Attributes['X'], StrToFloat(Node.Attributes['Y'])+Node.Attributes['H']]);
                              end;

                              //���û�л�������ת����һ��֧����,����Ƶ���ǰ��������������ӵ���
                              if not bTmp then begin
                                   DrawPoints([X,Y+H,  X,StrToFloat(Node.Attributes['Y'])+Node.Attributes['H']-SV]);
                              end;

                              //����ײ�����һ�����¼�ͷ
                              DrawArrow(X,Y+H-iDeltaY/2,True);

                         end;

                         //
                    end;

                    rtCase_Item,rtCase_Default,rtIF_ElseIf : begin
                         //�����ǰ�ӿ�δչ��,�����һ��
                         if (Node.Attributes['Expanded']=False) then begin
                              if Node.HasChildNodes then begin
                                   iTmp := Y;
                                   DrawBlock(x,iTmp,'... ...',True);
                                   //�½���
                                   DrawPoints([X,iTmp+BH,  X,iTmp+BH+SV]);

                              end;
                         end ;
                    end;

                    //
                    rtTry : begin
                         //����Try
                         DrawTry(X,Y,RTtoStr(Node.Attributes['Mode']),True,0);

                         //����End of Try
                         //iTmp := Y+H-BH-SV;
                         //DrawTry(X,iTmp,'TRY END',True,2);
                    end;
                    //
                    rtTry_Except,rtTry_Finally,rtTry_Else : begin
                         //����
                         DrawTry(X,Y,RTtoStr(Node.Attributes['Mode']),not Node.Attributes['Expanded'],1);
                    end;

               else

               end;
               //�ݹ�������ӽڵ�
               if Node.Attributes['Expanded'] then begin
                    for II:=0 to Node.ChildNodes.Count-1 do begin
                         DrawNodeFlowchart(Node.ChildNodes[II]);
                    end;
               end;
          except
               ShowMessage('Error when DrawNodeFlowchart! '+RTtoStr(Node.Attributes['Mode']));
          end;
     end;
     procedure ClearNodeWHE(Node:IXMLNode);
     var
          II   : Integer;
     begin
          Node.AttributeNodes.Delete('W');
          Node.AttributeNodes.Delete('H');
          Node.AttributeNodes.Delete('E');
          for II:=0 to Node.ChildNodes.Count-1 do begin
               ClearNodeWHE(Node.ChildNodes[II]);
          end;
     end;


     function GetNodeWHE(Node:IXMLNode):TNodeWHE;
     var
          iiCode    : Integer;
          KK        : Integer;
          xnFirst   : IXMLNode;
          xnNext    : IXMLNode;
          rChild    : TNodeWHE;
          rExtra    : TNodeWHE;
     begin
          //����Ѽ����,��ֱ�ӳ����
          if Node.HasAttribute('W') then begin
               Result.W  := Node.Attributes['W'];
               Result.H  := Node.Attributes['H'];
               Result.E  := Node.Attributes['E'];
               //
               Exit;
          end;
          //
          Result.W  := -1;
          Result.H  := -1;
          Result.E  := -1;
          if Node.Attributes['Mode']=rtBlock_Code then begin
               //��������
               if (Node.Attributes['ShowDetailCode']=2)or((grConfig.ShowDetailCode=False) and (Node.Attributes['ShowDetailCode']<>1)) then begin
                    Node.Attributes['W']   := BW*2;
                    Node.Attributes['H']   := BH+Sv;
                    Node.Attributes['E']   := 0;
               end else begin
                    //<��������
                    slTmp     := TStringList.Create;
                    slTmp.Text     := GetNodeText(Node);
                    Node.Attributes['W']   := BW*2;
                    for iiCode:=0 to slTmp.Count-1 do begin
                         slTmp[iiCode]   := Trim(slTmp[iiCode]);
                         Node.Attributes['W']   := Max(Node.Attributes['W'],GetGPTextWidth(slTmp[iiCode]+'A   A'));
                    end;
                    //ɾ�����һ�п���
                    if slTmp.Count>0 then begin
                         if slTmp[slTmp.Count-1]='' then begin
                              slTmp.Delete(slTmp.Count-1);
                         end;
                    end;
                    //���浽����
                    sText     := slTmp.Text;
                    iiCode     := slTmp.Count;
                    Node.Attributes['Text']  := slTmp.Text;
                    //
                    slTmp.Destroy;
                    //>


                    //���㳤��
                    Node.Attributes['H']   := Max(BH,GetGPTextHeight(Node.Attributes['Text']+#13+'AA'+#13+'AA'))+Sv;
                    Node.Attributes['E']   := 0;
                    //ȡ��
                    Node.Attributes['W']     := Round(Node.Attributes['W']);
                    Node.Attributes['H']     := Round(Node.Attributes['H']);
               end;
               //
               Result.W  := Node.Attributes['W'];
               Result.H  := Node.Attributes['H'];
               Result.E  := Node.Attributes['E'];
          end else if (Node.HasChildNodes=False)and (not InModes(Node.Attributes['Mode'],[rtCase_Item,rtCase_Default,rtTry_Except,rtTry_Finally])) then begin
               //������ģ��
               Node.Attributes['W']   := BW*2;
               Node.Attributes['H']   := BH+Sv;
               Node.Attributes['E']   := 0;
               //
               Result.W  := Node.Attributes['W'];
               Result.H  := Node.Attributes['H'];
               Result.E  := Node.Attributes['E'];
          end else if (not (Node.Attributes['Expanded']))and (not InModes(Node.Attributes['Mode'],[rtCase_Item,rtCase_Default])) then begin
               Node.Attributes['W']   := BW*2;
               Node.Attributes['H']   := BH+sv;
               Node.Attributes['E']   := 0;
               //
               Result.W  := Node.Attributes['W'];
               Result.H  := Node.Attributes['H'];
               Result.E  := Node.Attributes['E'];
          end else begin
               if Node.ChildNodes.Count>0 then begin
                    xnFirst   := Node.ChildNodes[0];
                    rChild    := GetNodeWHE(xnFirst);
               end;

               //ָ��Ĭ�ϵ�WHE
               Node.Attributes['W']   := BW*2;
               Node.Attributes['H']   := BH+sv;
               Node.Attributes['E']   := 0;

               //���ݸ������͵õ������W,H,E
               case Node.Attributes['Mode'] of
                    //<IF
                    rtIF : begin
                         //�Զ��֧����Ƿ�չ���ֿ����д���
                         for KK:=0 to Node.ChildNodes.Count-1 do begin
                              if KK=0 then begin
                                   xnFirst   := Node.ChildNodes.First;
                                   rChild    := GetNodeWHE(xnFirst);
                                   Node.Attributes['E']   := rChild.E;
                                   Node.Attributes['W']   := rChild.W;
                                   Node.Attributes['H']   := BH*2+SV*2+rChild.H;
                              end else begin
                                   xnFirst   := xnFirst.NextSibling;
                                   rChild    := GetNodeWHE(xnFirst);
                                   //
                                   Node.Attributes['W']   := Node.Attributes['W']+SH+rChild.E+rChild.W;
                                   Node.Attributes['H']   := Max(Node.Attributes['H'],rChild.H+BH*2+SV*2);
                              end;
                         end;

                    end;//IF>

                    //<For
                    rtFor : begin
                         Node.Attributes['W']   := rChild.W + Sh;
                         Node.Attributes['H']   := rChild.H + BH+Sv*3;
                         Node.Attributes['E']   := rChild.E + Sh;
                         //>
                    end;
                    //For>

                    //<While
                    rtWhile : begin
                         Node.Attributes['W']   := rChild.W + Sh;
                         Node.Attributes['H']   := rChild.H + BH*2+Sv*4;
                         Node.Attributes['E']   := rChild.E + Sh;
                    end;
                    //While>

                    //<Repeat
                    rtRepeat : begin
                         Node.Attributes['W']   := rChild.W + Sh;
                         Node.Attributes['H']   := rChild.H + BH*2+Sv*4;
                         Node.Attributes['E']   := rChild.E + Sh;
                    end;
                    //Repeat>

                    //<Case
                    rtCase : begin
                         //<������
                         if Node.ChildNodes.Count=0 then begin
                              ShowMessageFmt('GetNodeWHE error! CASE ChildCount = %d',[Node.ChildNodes.Count]);
                         end;
                         //>
                         //�Է�֧����Ƿ�չ���ֿ����д���
                         for KK:=0 to Node.ChildNodes.Count-1 do begin
                              if KK=0 then begin
                                   xnFirst   := Node.ChildNodes.First;
                                   rChild    := GetNodeWHE(xnFirst);
                                   Node.Attributes['E']   := rChild.E;
                                   Node.Attributes['W']   := rChild.W;
                                   Node.Attributes['H']   := BH*2+SV*2+rChild.H;
                              end else begin
                                   xnFirst   := xnFirst.NextSibling;
                                   rChild    := GetNodeWHE(xnFirst);
                                   //
                                   Node.Attributes['W']   := Node.Attributes['W']+SH*2+rChild.E+rChild.W;
                                   Node.Attributes['H']   := Max(Node.Attributes['H'],BH*2+SV*2+rChild.H);
                              end;
                         end;
                         //
                         Node.Attributes['H']   := Node.Attributes['H']+SV*2;

                    end;
                    //Case>

                    //<rtCase_Item,rtCase_Default
                    rtCase_Item,rtCase_Default : begin
                         if Node.ChildNodes.Count>0 then begin
                              if Node.Attributes['Expanded'] then begin
                                   for KK:=0 to Node.ChildNodes.Count-1 do begin
                                        if KK=0 then begin
                                             xnFirst   := Node.ChildNodes.First;
                                             rChild    := GetNodeWHE(xnFirst);
                                             Node.Attributes['E']   := rChild.E;
                                             Node.Attributes['W']   := rChild.W;
                                             Node.Attributes['H']   := rChild.H;
                                        end else begin
                                             xnFirst   := xnFirst.NextSibling;
                                             rChild    := GetNodeWHE(xnFirst);
                                             //
                                             Node.Attributes['E']   := Max(Node.Attributes['E'],rChild.E);
                                             Node.Attributes['W']   := Max(Node.Attributes['W'],rChild.W);
                                             Node.Attributes['H']   := Node.Attributes['H']+rChild.H;
                                        end;
                                   end;
                              end else begin //��£״̬
                                   Node.Attributes['W']   := BW*2;
                                   Node.Attributes['E']   := 0;
                                   Node.Attributes['H']   := BH+SV;
                              end;
                         end else begin //���ӿ�
                              Node.Attributes['W']   := BW*2;
                              Node.Attributes['E']   := 0;
                              Node.Attributes['H']   := 0;
                         end;
                    end;
                    //rtCase_Item,rtCase_Default>

                    //<Try
                    rtTry : begin

                         //
                         for KK:=0 to Node.ChildNodes.Count-1 do begin
                              if KK=0 then begin
                                   xnFirst   := Node.ChildNodes.First;
                                   rChild    := GetNodeWHE(xnFirst);
                                   Node.Attributes['E']   := rChild.E;
                                   Node.Attributes['W']   := rChild.W;
                                   Node.Attributes['H']   := rChild.H+BH*2+SV*2;
                              end else begin
                                   xnFirst   := xnFirst.NextSibling;
                                   rChild    := GetNodeWHE(xnFirst);
                                   //
                                   Node.Attributes['E']   := Max(Node.Attributes['E'],rChild.E);
                                   Node.Attributes['W']   := Max(Node.Attributes['W'],rChild.W);
                                   Node.Attributes['H']   := Node.Attributes['H']+rChild.H;
                              end;
                         end;
                    end;
                    //Try>

                    //<Try_Except,Try_Finally
                    rtTry_Except,rtTry_Finally : begin
                         if Node.Attributes['Expanded'] then begin
                              for KK:=0 to Node.ChildNodes.Count-1 do begin
                                   if KK=0 then begin
                                        xnFirst   := Node.ChildNodes.First;
                                        rChild    := GetNodeWHE(xnFirst);
                                        Node.Attributes['E']   := rChild.E;
                                        Node.Attributes['W']   := rChild.W;
                                        Node.Attributes['H']   := rChild.H+BH+SV;
                                   end else begin
                                        xnFirst   := xnFirst.NextSibling;
                                        rChild    := GetNodeWHE(xnFirst);
                                        //
                                        Node.Attributes['E']   := Max(Node.Attributes['E'],rChild.E);
                                        Node.Attributes['W']   := Max(Node.Attributes['W'],rChild.W);
                                        Node.Attributes['H']   := Node.Attributes['H']+rChild.H;
                                   end;
                              end;
                         end else begin
                              Node.Attributes['E']   := 0;
                              Node.Attributes['W']   := BW*2;
                              Node.Attributes['H']   := BH+SV;
                         end;
                    end;
                    //Try_Except,Try_Finally>


               else
                    //
                    for KK:=0 to Node.ChildNodes.Count-1 do begin
                         if KK=0 then begin
                              xnFirst   := Node.ChildNodes.First;
                              rChild    := GetNodeWHE(xnFirst);
                              Node.Attributes['E']   := rChild.E;
                              Node.Attributes['W']   := rChild.W;
                              Node.Attributes['H']   := rChild.H;
                         end else begin
                              xnFirst   := xnFirst.NextSibling;
                              rChild    := GetNodeWHE(xnFirst);
                              //
                              Node.Attributes['E']   := Max(Node.Attributes['E'],rChild.E);
                              Node.Attributes['W']   := Max(Node.Attributes['W'],rChild.W);
                              Node.Attributes['H']   := Node.Attributes['H']+rChild.H;
                         end;
                    end;
               end; //end of case
               //
               Result.W  := Node.Attributes['W'];
               Result.H  := Node.Attributes['H'];
               Result.E  := Node.Attributes['E'];
          end;
     end;

begin
     Result    := 0;


     //<�õ�����ͼ����
     fCurScale := 1;
     while True do begin
          Config.Scale   := Config.Scale*fCurScale;
          oFont     := TGPFont.Create(Config.FontName, Config.FontSize*Config.Scale, FontStyleRegular, UnitPixel);
          //
          BW   := Config.BaseWidth*Config.Scale;
          BH   := Config.BaseHeight*Config.Scale;
          SH   := Config.SpaceHorz*Config.Scale;
          SV   := Config.SpaceVert*Config.Scale;
          if BW=0 then begin
               BW   := 80;
          end;
          if BH=0 then begin
               BH   := 30;
          end;
          if SH=0 then begin
               SH   := 20;
          end;
          if SV=0 then begin
               SV   := 20;
          end;
          //>

          //
          Image.Canvas.Font.Size   := Round(grConfig.FontSize*Config.Scale);
          Image.Canvas.Font.Name   := grConfig.FontName;

          //-----------------------------------�����ģ��Ĵ�С-----------------------------------//
          //����ǰ�����ԭ����WHE
          ClearNodeWHE(Node);
          //�õݹ��������ģ��Ĵ�С
          GetNodeWHE(Node);    

          //-----------------------------------�����ģ���λ��-----------------------------------//
          //�ӵ�һ����ʼ, �Ե�ǰ��Ϊ����, ���㵱ǰ����ӿ��λ��
          xnNode    := Node;
          xnNode.Attributes['X']   := SH+xnNode.Attributes['E']+BW;
          xnNode.Attributes['Y']   := BH+SV*2;
          SetNodePosition(xnNode);      //�ݹ�����ģ���λ��


          //---------------------------��������ͼ��׼������---------------------------------------//
          //�����ǰ����ͼû������,������Ϊ��Сһ����
          if xnNode.Attributes['W']<=0 then begin
               xnNode.Attributes['W']   := BW*2;
               xnNode.Attributes['H']   := BH+Sv;
          end;

          //����ͼ���С
          iImageW   := Round(StrToFloat(xnNode.Attributes['E'])+xnNode.Attributes['W']+SH*2);
          iImageH   := Round(xnNode.Attributes['H']+Sv*2+2*(BH+SV));

          //���������Ⱥ͸߶�
          if (iImageW>giMaxWidth)or(iImageH>giMaxHeight) then begin
               if (iImageW>giMaxWidth)or(iImageH>giMaxHeight) then begin
                    if iImageW/iImageH>giMaxWidth/giMaxHeight then begin
                         fCurScale := giMaxWidth/iImageW;
                         iImageH   := Round(giMaxWidth*(iImageH/iImageW));
                         iImageW   := giMaxWidth;
                    end else begin
                         fCurScale := giMaxHeight/iImageH;
                         iImageW   := Round(giMaxHeight*(iImageW/iImageH));
                         iImageH   := giMaxHeight;
                    end;
               end;
               //
               //Break;
          end else begin
               Break;
          end;
     end;

     //
     Image.Width    := iImageW;
     Image.Height   := iImageH;
     Image.Picture.Bitmap.Width      := iImageW;
     Image.Picture.Bitmap.Height     := iImageH;
     Image.Picture.Assign(nil);

     //���ɸ���GDI+����
     oGraph    := TGPGraphics.Create(Image.Canvas.Handle);
     oPen      := TGPPen.Create(ColorToGP(Config.LineColor),1);
     oFont     := TGPFont.Create(Config.FontName, Config.FontSize*Config.Scale, FontStyleRegular, UnitPixel);
     oFontB    := TGPFont.Create(Config.FontName, Config.FontSize*Config.Scale, FontStyleBold, UnitPixel);
     oFontBrh  := TGPSolidBrush.Create(ColorToGP(Config.FontColor));
     oBrush    := TGPSolidBrush.Create(ColorToGP(Config.FillColor));
     oPath     := TGPGraphicsPath.Create();
     oFormat   := TGPStringFormat.Create;
     oFormat.SetAlignment(StringAlignmentCenter);
     oFormat.SetLineAlignment(StringAlignmentCenter);
     //���÷�ʧ��
     oGraph.SetSmoothingMode(SmoothingModeAntiAlias);
     oGraph.SetTextRenderingHint(TextRenderingHintAntiAlias);



     //-----------------------��������ͼ(�˺�Ĵ���Ӧ�ܹ���)--------------------------------------//
     //<���ƿ�ʼ�ͽ�����־
     //��ʼ��־
     X    := Node.Attributes['X'];
     Y    := SV;
     DrawRoundRect(X,Y,'START');
     //�½���
     DrawPoints([X,Y+BH,  X,Y+BH+SV]);
     //������־
     X    := Node.Attributes['X'];
     Y    := Round(StrToFloat(Node.Attributes['Y']))+Round(StrToFloat(Node.Attributes['H']));
     DrawRoundRect(X,Y,'END');
     //>

     //�ݹ��������ͼ
     DrawNodeFlowchart(Node);

end;


end.