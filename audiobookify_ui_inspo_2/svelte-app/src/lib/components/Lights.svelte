<script lang="ts">
    import { T } from "@threlte/core";
</script>

<T.AmbientLight intensity={0.4} />

<T.SpotLight
    position={[5, 10, 5]}
    angle={0.5}
    penumbra={1}
    intensity={2}
    castShadow
/>

<T.PointLight position={[-5, 5, 5]} intensity={0.5} color="#ffd700" />
<T.PointLight position={[0, 2, 2]} intensity={1} distance={5} color="#ffffff" />
