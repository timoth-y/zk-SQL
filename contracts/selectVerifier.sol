//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );

/*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }
    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-add-failed");
    }
    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length,"pairing-lengths-failed");
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-opcode-failed");
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}
contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = Pairing.G2Point(
            [4252822878758300859123897981450591353533073413197771768651442665752259397132,
             6375614351688725206403948262868962793625744043794305715222011528459656738731],
            [21847035105528745403288232691147584728191162732299865338377159692350059136679,
             10505242626370262277552901082094356697409835680220590971873171140371331206856]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.IC = new Pairing.G1Point[](77);
        
        vk.IC[0] = Pairing.G1Point( 
            18967163067060321708000354922917534753021118007429394442914459794043479841502,
            15869769699873067897500406398046609925977767298536772490669026496924166662261
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            2393395129768209212813157813243602672477521114721862792513796734981403262955,
            15747867323722938180255977261933111302063035659508633529975197095589537615502
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            20357763174977569433452735035976364460707829732682877576731039753764709877219,
            15612476313869050387673000949760128179469058671286580537428348808837181255998
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            9893759316896427580566098216948740488454429575737865753906617053494397370173,
            19532848579478024072715584724834533949024358946451279210545083896710454344865
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            885577605760033853025828263809858016281319537063528480648511884811276583200,
            13921927923365804566750147364403157717900711000962039333838094889546500520017
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            11864150272643785323462079172435151680669438889464248384164302528704348146448,
            15448580138881923139395474114729401798834272858619687678529185022562009004614
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            16137682162741022192056749651147960861149932847210417154135888067486840719857,
            8516003676591569168294460729427488554193664496021503307919774296901227595120
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            6076134722704073847353605151925820752365903397283527959621072451753115069284,
            17225031297251141959715223560625565067256004172830342266194829363878415405963
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            9188216523072339347224673881257289433481905877082391137599942264746736351727,
            7662160387548306114219266518194635405446042008949922409604330731344331843471
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            820605366865532979280484006825870179702633944011506383675049364689043947296,
            5563440005951338467154441168851542546138035556828883838240193171496150952778
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            15634145642822183852863016355896568312552117202643857422117871198913099282271,
            5460387911916385914268374126282463729325144836962126131262122234493608814164
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            11205217533026102233299569811958705776184343571529219153064341263470638630869,
            3943854749910301325562011165214614230280577032943827243868613387968246477610
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            7348421355771208501135437185049628666462022902330123975271915739294015588949,
            2632496256842827665151236173006900808399684536906084009829257745001294663631
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            10607532555859255164412892619781344496765786958678073941239067846415290472968,
            16919087433262662957493548901614810457785925322498240323320704885173025214410
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            20022737618077079045363429736730626284722150897490061013417447619399172694603,
            5843570135952298534723517848468969144961267831106160945969469501272559407066
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            20789857230608081615211750264740816487938278346693165426971445310009324308800,
            10571846956477543964620030542872268712782263503111075277722935165579836666428
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            2441364675020900235921664363817004240308693407484595081665836642357159053048,
            2073484337213227699939280424527706669280555656631783265993328938060843579432
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            3017247416999798630717696171470038310478294409056493353287347219141317073351,
            20646340046416364244246227086474311339214326255921085345818104136069223154886
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            2185629289030353310136084406834019584607298319485035199245322416536766921660,
            12793809423372611620010274131888238483939517665733519090694411094076501300005
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            13209328208142022214839967630643057120023459700636005012892873042953116385285,
            321211938992586163006374002093120909280415201480687706151584602334321275164
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            10120462046030233079291181774680649212820160187730788491732120806156296643312,
            5099255689962572257097211619875518248770954794637586476707003635921236876368
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            5159301381802197965431101062093638506268333846583312829877398039749350527112,
            18660201523153505103090354440358888569298737106697426468513351246331287417395
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            11613603474999948822841393343478912675678048657340798833588689654670450161781,
            8627939871398619216822696600126873990386248935963943044589808789093832727451
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            19240622492514056038779563415629126871194706916698828714359823600925187017437,
            19586247553609509238354140239717831883233352624822719740796418734487530983415
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            20838692882484201086655791383094649831331708518624584500089547806519997666394,
            2003908370801639510121566896702778394546190912330485153993588764045470567558
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            596055575706253664183655625679858601659731018170158682839155043415280573750,
            20594863579220917804026802821296245930175580101744963192366996573991306322262
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            12015756656567016004317726157217998365484821838183647892322827343696311122992,
            5967034439353760582553870383827199169290325367429777306076896321808265278507
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            21444687433683580480117755988899188796283195523892789362906156466600264722100,
            8586827953819765678627705246862934526665048760686496060907564502803359522227
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            21174277209982247992698460250642322519873317968601426834213635396417920427252,
            21497652658235789886175139694565802633629582376824544082694737334053969701558
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            11225127743006784508236967676632550515538143418244658950803695310411044444423,
            1859789190128569006274484147827775054676182357314733101911730856414575511178
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            5720365186099588463808754042188597605285712745332709825251188017004105055622,
            10445472371558542364308685373116391331306901457885485248100978652176345981959
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            11190307502062686343607616793335224983025618458199715618482538672995949805776,
            15850070175226635067070283981635016662427098515247880528812665064502719035111
        );                                      
        
        vk.IC[32] = Pairing.G1Point( 
            4280716559997767635467646199353966744068365918576179576047450310515872896773,
            17002845493911290193630968520418520323617043351622376017988549618432746794728
        );                                      
        
        vk.IC[33] = Pairing.G1Point( 
            16984398320297763011868628318638212225196893294476820474457802705061715221592,
            4374743858282758878917154185827485729354870725190273004320921294846610921170
        );                                      
        
        vk.IC[34] = Pairing.G1Point( 
            15395907182327603102572256917979596754143027123528811324168486897879271609592,
            15527557801449631918509995246083508318947179345086548661789977296318357124034
        );                                      
        
        vk.IC[35] = Pairing.G1Point( 
            19492218603228082341945669881940333534517576028940016110667842727871623926130,
            17125383377236203244674813129166115279609548007201493681731143414023411850586
        );                                      
        
        vk.IC[36] = Pairing.G1Point( 
            7436590217774871692644141856975705247620549219900191177680927929975157227058,
            2619321133770983559145186915181386309820297031466562099988332216320761281809
        );                                      
        
        vk.IC[37] = Pairing.G1Point( 
            3211122241535250511180417786814149132960792182857979380294706741883381651810,
            1801433981888111848050094752970684656284696356762609918735010057968524141612
        );                                      
        
        vk.IC[38] = Pairing.G1Point( 
            9415423980139457340678541022547272729440477320874219609127484950181991542232,
            19521437152919867732289833545467451325303991025219059825008151816118227852028
        );                                      
        
        vk.IC[39] = Pairing.G1Point( 
            20063572989368995346291746205757499407387966600395657322749464348679665365234,
            4443634245828980280910878421875679888936168417723491319863067252374976601750
        );                                      
        
        vk.IC[40] = Pairing.G1Point( 
            6328846695724185602267560711749932191040383009504318458021728909279543159728,
            11259342720265370811922370976981280311621566317885564906506505357951531289314
        );                                      
        
        vk.IC[41] = Pairing.G1Point( 
            7119092884468797621585178970469492147493771390230059370073562507454191248170,
            15136545092265694217989174480123071500032294269302744323715693454248647651717
        );                                      
        
        vk.IC[42] = Pairing.G1Point( 
            6368955909466741122455061145913744692632023558299219176581192714400158148821,
            6928091068720135600698204057835094440182387643671848718962651852220795672773
        );                                      
        
        vk.IC[43] = Pairing.G1Point( 
            8038595949067845724869594529028146839141274741486130690693106015960687339464,
            1120159523502558095649679580736101622892644596217732435283283615612364358448
        );                                      
        
        vk.IC[44] = Pairing.G1Point( 
            2219440329011849524887748048812525404320089139276659733819651371515086507997,
            11842040137752131845840593095376954204152688414522737921114281724556119750345
        );                                      
        
        vk.IC[45] = Pairing.G1Point( 
            18179220631741165248034261938331031002343930649707471245270451965914496559617,
            6875140317821359760066426752927948082056293774999825154472968241196654233549
        );                                      
        
        vk.IC[46] = Pairing.G1Point( 
            10699438239304795805127680983442665757976156262709935080338905799004886084466,
            17731070290086262300832778192383996667148781127359492324955897873879985253316
        );                                      
        
        vk.IC[47] = Pairing.G1Point( 
            18009586051892529756820309071516523511304961339422065719357633030633012726633,
            5001886947163132059426863569641921986060779940328562180632354465638205201037
        );                                      
        
        vk.IC[48] = Pairing.G1Point( 
            852047712453585079426227177416946007270788675856944507767387606599181046268,
            19793702646843658866116183948258505768597879546548708342242353991434487377918
        );                                      
        
        vk.IC[49] = Pairing.G1Point( 
            932558363058832883511596064115830582762586587284936940428506011449548810824,
            11803768917284243800255145097471340013359891190290639384112818167316828218024
        );                                      
        
        vk.IC[50] = Pairing.G1Point( 
            12033408671959204392750458233423765429646487031316785562826381040604833855598,
            88856594831086523065482799615957752401318961452464860866441894343188922704
        );                                      
        
        vk.IC[51] = Pairing.G1Point( 
            3946102040290488837739853059231644536164501987487817488561345150899904773717,
            7173842171479397539732662658789016713317891949549102335260984327194167003819
        );                                      
        
        vk.IC[52] = Pairing.G1Point( 
            5976043008296422058580665637308867110349805725366124839719972132642846037598,
            2871893794237983868147612798116576926146595024863047579476834536270123172940
        );                                      
        
        vk.IC[53] = Pairing.G1Point( 
            11417735814290872591579734628975916388245204824378669043957980121951832407936,
            4030195400580092783825269018905412631326619515609863426645605448559356839760
        );                                      
        
        vk.IC[54] = Pairing.G1Point( 
            2767441412641272670191190990537123024184762949165292585907979481414718940027,
            10030752372134904738624945158131026076954281054264632218945175512502786020131
        );                                      
        
        vk.IC[55] = Pairing.G1Point( 
            16171712177333384397164583558698595114099921148817006525230574908610635661355,
            15841177841254791321350198020152908197552125145902587378636352029822756736011
        );                                      
        
        vk.IC[56] = Pairing.G1Point( 
            7290966592055579308470734251859818741788402713477887774996118178744059351483,
            1379093390458356466037009758624730605897782553193939184698220994450703780015
        );                                      
        
        vk.IC[57] = Pairing.G1Point( 
            18677490605444337695691253514075591359373253846475406824012254800234966149631,
            18178823936111775348469963477642111937037189634608110445812387349209202827216
        );                                      
        
        vk.IC[58] = Pairing.G1Point( 
            18553045946121729791356586033929225932798038470102151896729835914847318214285,
            11225184346132043646462563798543045155298174998105675801627386267345760306286
        );                                      
        
        vk.IC[59] = Pairing.G1Point( 
            16125528001924801974251103364069422019698651585987526922480489280745409544786,
            10863872898362054789560944017419881872350314450918275488261864309191390897388
        );                                      
        
        vk.IC[60] = Pairing.G1Point( 
            919438145658347708682964058535310662223438499318745660114052476513359493147,
            10351455793281619585482487174260995057636325340991921307699415473817085723856
        );                                      
        
        vk.IC[61] = Pairing.G1Point( 
            9032959975439074767662103233587879776924603053570815897698500184549303124006,
            15578135157918764460879697933558985102767505121093493204828476678192729561120
        );                                      
        
        vk.IC[62] = Pairing.G1Point( 
            6327163708783749733507576066550659012009834859160619655283575226715104734496,
            5564496724391111191819391357106102618813259249656499333900919935701204473093
        );                                      
        
        vk.IC[63] = Pairing.G1Point( 
            11348905375375240601762532673545461375768643010449966922559039889814382082105,
            10512862786307440876523360134032032206731676627929588124800654253004477026240
        );                                      
        
        vk.IC[64] = Pairing.G1Point( 
            5618741382598386069509569895340573248272684998837766767976080125992114263788,
            15781925907726724223177772720635354851971511625657592114728089517490205249502
        );                                      
        
        vk.IC[65] = Pairing.G1Point( 
            11626234272835227406365864299301603821526696107702325737889661114995170182550,
            14929178443519878737111010381492948278239848027628300071620485842912799869630
        );                                      
        
        vk.IC[66] = Pairing.G1Point( 
            5613352634392279333896348607055167095083879859249128761634834619106125582979,
            14253139971203846217905708120597321112157610822379709849276693340217577259166
        );                                      
        
        vk.IC[67] = Pairing.G1Point( 
            18719002422886982064132463530498962823392439540048883428871636833972718589536,
            20615803453959080877850395672650041448608972827498726296018568941814754563749
        );                                      
        
        vk.IC[68] = Pairing.G1Point( 
            21413299642474940683572265528806236146073168018507527399362104657578307709165,
            12294615380744304245962941315685932975600312056240568200071870713736757999531
        );                                      
        
        vk.IC[69] = Pairing.G1Point( 
            17584005670155259830833248954567771694379607988908172260575466444579094989588,
            12880794375942870685836620840406985263431367236569230712394935426519628373955
        );                                      
        
        vk.IC[70] = Pairing.G1Point( 
            18791586309368356769637939931721749184949423213505797671020977730028241149860,
            3613392998577960301143106378839229935156752948236602022912880773766825383885
        );                                      
        
        vk.IC[71] = Pairing.G1Point( 
            1782681876870036808819223717402633226493823713065879242154756447112233995995,
            3142499255388041960897935023230515374092307535040556991576275767883391492109
        );                                      
        
        vk.IC[72] = Pairing.G1Point( 
            14165733365426240603028067488769625011471382858541663563530605875061628059768,
            9526023201443142175665355501201940970379397531613370078995487460583256194284
        );                                      
        
        vk.IC[73] = Pairing.G1Point( 
            18360697378540029014200051979405342010989242025535202273804563489940528298298,
            19147422937229644158938384513684304774176275692435832984150624846882620494044
        );                                      
        
        vk.IC[74] = Pairing.G1Point( 
            14414216959589356329012224238381079207676726910808125344516923786867728233792,
            20367858434563127048424509475738177043221383642269423211827440349364150429095
        );                                      
        
        vk.IC[75] = Pairing.G1Point( 
            1428120129629557068283321235614042259374879670972031099478162871604736446215,
            21075948279411150337837999651527219012556817915064140229172526147447899918574
        );                                      
        
        vk.IC[76] = Pairing.G1Point( 
            3140555201324483740430284688274479751290879932033555913274026599319870028999,
            574296250747545082189301583476780058136428476418284795555357779839710322901
        );                                      
        
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[76] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}