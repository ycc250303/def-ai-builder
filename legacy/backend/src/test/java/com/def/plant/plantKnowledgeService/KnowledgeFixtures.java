package com.def.plant.plantKnowledgeService;

/** 自行编写的网页样例，只模拟来源结构，不保存来源网站全文。 */
public final class KnowledgeFixtures {
    private KnowledgeFixtures() { }

    public static String search(String... paths) {
        var html = new StringBuilder("<main><input id='plant_object_count' value='" + paths.length + "'><div id='plant_list'>");
        for (String path : paths) html.append("<div class='plant'><h2><a href='").append(path)
                .append("'>Source title</a></h2><span class='common_names'>Golden Pothos</span></div>");
        return html.append("</div></main>").toString();
    }

    public static String detail() {
        return """
                <main><aside><p>Ignore nearby plants and advertisements.</p></aside>
                <div id='plant_detail'><h1>Reference plant <small><button>Play pronunciation</button></small></h1>
                <dl><dt>Description</dt><dd>
                <p>In winter, water only when the potting soil is dry. Avoid standing water.</p>
                <p>Yellow leaves may follow overwatering. Check drainage before watering again.</p>
                <p>Grow in bright indirect light at temperatures above 15 degrees C.</p>
                <p>Re-pot in spring and prune long stems. Propagate using stem cuttings.</p>
                </dd></dl>
                <ul><li><dl><span class='group_name'>Cultural Conditions:</span>
                <dt>Light:</dt><dd>Partial Shade</dd><dd>Dappled Sunlight</dd>
                <dt>Soil Drainage:</dt><dd>Good Drainage</dd>
                <dt>USDA Plant Hardiness Zone:</dt><dd>10a</dd>
                </dl></li></ul></div></main>
                """;
    }
}
